// App/ConfigEditorView.swift
import SwiftUI

struct ConfigEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var cloudflareAPIBaseURLText: String
    @State private var controlPlaneURLText: String
    @State private var accountId: String
    @State private var tunnelId: String
    @State private var cloudflareAPIToken: String
    @State private var controlBearerToken: String
    @State private var serviceTokenId: String
    @State private var serviceTokenSecret: String
    @State private var controlPlaneAuthMode: ControlPlaneAuthMode

    let onSave: (TunnelConfiguration) -> Void

    init(configuration: TunnelConfiguration, onSave: @escaping (TunnelConfiguration) -> Void) {
        _cloudflareAPIBaseURLText = State(initialValue: configuration.cloudflareAPIBaseURL.absoluteString)
        _controlPlaneURLText = State(initialValue: configuration.controlPlaneURL?.absoluteString ?? "")
        _accountId = State(initialValue: configuration.accountId)
        _tunnelId = State(initialValue: configuration.tunnelId ?? "")
        _cloudflareAPIToken = State(initialValue: "")
        _controlBearerToken = State(initialValue: "")
        _serviceTokenId = State(initialValue: "")
        _serviceTokenSecret = State(initialValue: "")
        _controlPlaneAuthMode = State(initialValue: configuration.controlPlaneAuthMode)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Cloudflare API") {
                    TextField("https://api.cloudflare.com", text: $cloudflareAPIBaseURLText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("Account ID", text: $accountId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Tunnel ID", text: $tunnelId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("API Token", text: $cloudflareAPIToken)
                }

                Section("Control Backend") {
                    TextField("https://control.example.com", text: $controlPlaneURLText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Picker("Auth", selection: $controlPlaneAuthMode) {
                        Text("None").tag(ControlPlaneAuthMode.none)
                        Text("Bearer Token").tag(ControlPlaneAuthMode.bearerToken)
                        Text("Service Token").tag(ControlPlaneAuthMode.serviceToken)
                    }

                    if controlPlaneAuthMode == .bearerToken {
                        SecureField("Bearer Token", text: $controlBearerToken)
                    }

                    if controlPlaneAuthMode == .serviceToken {
                        TextField("Service Token Client ID", text: $serviceTokenId)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Service Token Secret", text: $serviceTokenSecret)
                    }
                }

                Section {
                    Text("Leave credential fields empty to keep the current Keychain values.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(accountId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || URL(string: cloudflareAPIBaseURLText) == nil)
                }
            }
        }
    }

    private func save() {
        guard let cloudflareAPIBaseURL = URL(string: cloudflareAPIBaseURLText) else { return }

        let credentialStore = TunnelCredentialStore.shared
        let cleanCloudflareToken = cloudflareAPIToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBearerToken = controlBearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanServiceTokenId = serviceTokenId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanServiceTokenSecret = serviceTokenSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanCloudflareToken.isEmpty {
            try? credentialStore.saveCloudflareAPIToken(cleanCloudflareToken)
        }
        if !cleanBearerToken.isEmpty {
            try? credentialStore.saveControlPlaneBearerToken(cleanBearerToken)
        }
        if !cleanServiceTokenId.isEmpty, !cleanServiceTokenSecret.isEmpty {
            try? credentialStore.saveControlPlaneServiceToken(clientId: cleanServiceTokenId, clientSecret: cleanServiceTokenSecret)
        }

        let cleanControlURL = controlPlaneURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTunnelId = tunnelId.trimmingCharacters(in: .whitespacesAndNewlines)

        onSave(
            TunnelConfiguration(
                cloudflareAPIBaseURL: cloudflareAPIBaseURL,
                controlPlaneURL: cleanControlURL.isEmpty ? nil : URL(string: cleanControlURL),
                accountId: accountId.trimmingCharacters(in: .whitespacesAndNewlines),
                tunnelId: cleanTunnelId.isEmpty ? nil : cleanTunnelId,
                cloudflareAuthMode: .apiToken,
                controlPlaneAuthMode: controlPlaneAuthMode
            )
        )
        dismiss()
    }
}
