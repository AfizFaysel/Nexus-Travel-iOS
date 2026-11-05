import SwiftUI
import UniformTypeIdentifiers

struct PassengerDetailsScreenRoute: View {
    @State private var viewModel: PassengerDetailsViewModel
    @State private var task: Task<Void, Never>?
    let router: Router
    let bookingFlowState: BookingFlowState

    init(viewModel: PassengerDetailsViewModel, router: Router, bookingFlowState: BookingFlowState) {
        _viewModel = State(initialValue: viewModel); self.router = router; self.bookingFlowState = bookingFlowState
    }

    var body: some View {
        PassengerDetailsScreen(viewModel: viewModel) { submit() }
            .task {
                if bookingFlowState.consumePassengerSubmissionAfterAuthentication() { submit() }
            }
            .onChange(of: bookingFlowState.submitPassengerDetailsAfterAuth) {
                if bookingFlowState.consumePassengerSubmissionAfterAuthentication() { submit() }
            }
            .onDisappear { task?.cancel() }
    }

    private func submit() {
        guard task == nil else { return }
        let transition = bookingFlowState.beginPassengerSubmission()
        guard transition != .unavailable else { return }
        task = Task {
            do {
                try await viewModel.submit(authenticated: transition == .submit)
            } catch is CancellationError {
                task = nil
                return
            } catch {
                task = nil
                return
            }
            route(); task = nil
        }
    }

    private func route() {
        while let event = viewModel.consumeNavigationEvent() {
            switch event {
            case .back: router.pop()
            case .authenticate:
                bookingFlowState.preparePassengerSubmissionAuthentication()
                router.presentAuthentication(for: .booking)
            case let .seats(id): router.push(.seatSelection(.init(bookingId: id)))
            case .editSearch: router.popToRoot()
            }
        }
    }
}

struct PassengerDetailsScreen: View {
    @Bindable var viewModel: PassengerDetailsViewModel
    let onContinue: () -> Void
    @State private var importsDocument = false
    @State private var importingPassengerIndex = 0

    private var form: Binding<PassengerDetailsFormState> {
        Binding(get: { viewModel.forms[viewModel.activePassengerIndex] },
                set: { viewModel.forms[viewModel.activePassengerIndex] = $0 })
    }

    var body: some View {
        Form {
            if let message = viewModel.errorMessage {
                Section {
                    NexusFeedbackPanel(title: "We couldn't save your details", message: message)
                }
            }
            if viewModel.passengerTypes.count > 1 {
                Section("Travelers") {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(viewModel.passengerTypes.indices, id: \.self) { index in
                                Button(passengerLabel(at: index)) { viewModel.selectPassenger(index) }
                                    .buttonStyle(.bordered)
                                    .tint(index == viewModel.activePassengerIndex ? .accentColor : .secondary)
                                    .accessibilityAddTraits(index == viewModel.activePassengerIndex ? .isSelected : [])
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            Section("Passenger \(viewModel.activePassengerIndex + 1) · \(passengerTypeLabel)") {
                Picker("Title", selection: form.title) {
                    ForEach(["Mr", "Ms", "Mrs", "Mx"], id: \.self) { Text($0).tag($0) }
                }
                Picker("Gender", selection: form.gender) {
                    ForEach(["Male", "Female", "Other"], id: \.self) { Text($0).tag($0) }
                }
                TextField("First name", text: form.firstName).textContentType(.givenName)
                TextField("Last name", text: form.lastName).textContentType(.familyName)
                dateFields("Date of birth", day: form.dateOfBirthDay,
                           month: form.dateOfBirthMonth, year: form.dateOfBirthYear)
                    .onChange(of: viewModel.forms[viewModel.activePassengerIndex].dateOfBirthDay
                              + viewModel.forms[viewModel.activePassengerIndex].dateOfBirthMonth
                              + viewModel.forms[viewModel.activePassengerIndex].dateOfBirthYear) {
                        let index = viewModel.activePassengerIndex
                        viewModel.forms[index].dateOfBirth = viewModel.forms[index].dateOfBirthInput().parsed
                    }
                countryPicker("Nationality", selection: form.nationalityCountryCode)
            }
            Section("Passport") {
                TextField("Passport number", text: form.passportNumber)
                    .textInputAutocapitalization(.characters)
                dateFields("Expiry date", day: form.passportExpiryDay,
                           month: form.passportExpiryMonth, year: form.passportExpiryYear)
                    .onChange(of: viewModel.forms[viewModel.activePassengerIndex].passportExpiryDay
                              + viewModel.forms[viewModel.activePassengerIndex].passportExpiryMonth
                              + viewModel.forms[viewModel.activePassengerIndex].passportExpiryYear) {
                        let index = viewModel.activePassengerIndex
                        viewModel.forms[index].passportExpiryDate = viewModel.forms[index].passportExpiryInput().parsed
                    }
                countryPicker("Issuing country", selection: form.passportIssuingCountryCode)
                Button(viewModel.forms[viewModel.activePassengerIndex].passportDocument?.displayName ?? "Choose passport document", systemImage: NexusPlatformIconName.documentAdd.rawValue) {
                    importingPassengerIndex = viewModel.activePassengerIndex
                    importsDocument = true
                }
                .accessibilityHint("Choose a JPEG, PNG, or PDF up to 10 MB")
                if let error = viewModel.validation.error(for: .passportDocument) {
                    Text(error).foregroundStyle(.red)
                }
            }
            if viewModel.activePassengerIndex == 0 {
                Section("Contact details") {
                    TextField("Email", text: form.email).textContentType(.emailAddress)
                        .textInputAutocapitalization(.never).keyboardType(.emailAddress)
                    HStack {
                        TextField("Code", text: form.countryDialCode).frame(maxWidth: 90)
                        TextField("Mobile number", text: form.phoneNumber).keyboardType(.phonePad)
                    }
                }
            }
            if viewModel.validation.hasErrors {
                Section("Check these details") {
                    ForEach(viewModel.validation.summaryErrors, id: \.self) { Text($0).foregroundStyle(.red) }
                }
            }
            Section {
                Button(action: onContinue) {
                    if viewModel.isSubmitting { ProgressView().frame(maxWidth: .infinity) }
                    else { Text("Continue to seats").frame(maxWidth: .infinity) }
                }.disabled(viewModel.isSubmitting)
            }
        }
        .navigationTitle("Passenger Details")
        .fileImporter(isPresented: $importsDocument, allowedContentTypes: [.pdf, .jpeg, .png]) { result in
            guard case let .success(url) = result else { return }
            guard viewModel.forms.indices.contains(importingPassengerIndex) else { return }
            viewModel.forms[importingPassengerIndex].passportDocument = .init(
                uriString: url.absoluteString, displayName: url.lastPathComponent,
                mimeType: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
            )
        }
    }

    private var passengerTypeLabel: String {
        switch viewModel.passengerTypes[viewModel.activePassengerIndex] {
        case .adult: "Adult"
        case .child: "Child"
        case .infant: "Infant"
        }
    }

    private func passengerLabel(at index: Int) -> String {
        let type = viewModel.passengerTypes[index]
        let number = viewModel.passengerTypes.prefix(index + 1).filter { $0 == type }.count
        let label: String
        switch type {
        case .adult: label = "Adult"
        case .child: label = "Child"
        case .infant: label = "Infant"
        }
        return "\(label) \(number)"
    }

    private func dateFields(_ title: String, day: Binding<String>, month: Binding<String>,
                            year: Binding<String>) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("DD", text: day).keyboardType(.numberPad)
                TextField("MM", text: month).keyboardType(.numberPad)
                TextField("YYYY", text: year).keyboardType(.numberPad)
            }
        }
    }

    private func countryPicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            ForEach(CountryCatalog.countries, id: \.isoCode) { country in
                Text(country.countryName).tag(country.isoCode)
            }
        }
    }
}
