// App/ConfigEditorView.swift
// Settings screen – allows the user to configure their Cloudflare credentials

import SwiftUI

struct ConfigEditorView: View {

    @EnvironmentObject private var viewModel: TunnelViewModel
    @Environment(\.dismiss) private var dismiss

    // Local editing state – mirrors viewModel.config fields + the Keychain token
    @State private var apiToken: String   = ""
    @State private var tunnelId: String   = ""
    @State private var accountId: String  = ""
    @State private var baseURL: String    = ""

    @State private var saveError: String? = nil
    @State private var saved             = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // ── Credentials ───────────────────────────────────────────
                Section {
                    SecureField("API Token", text: $apiToken)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Cloudflare API Token")
                } footer: {
                    Text("Create a token at dash.cloudflare.com › Profile › API Tokens with Tunnel:Edit permission.")
                        .font(.caption)
                }

                // ── Tunnel details ────────────────────────────────────────
                Section("Tunnel Details") {
                    LabeledContent("Tunnel ID") {
                        TextField("xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", text: $tunnelId)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    LabeledContent("Account ID") {
                        TextField("32-char hex string", text: $accountId)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                }

                // ── Advanced ──────────────────────────────────────────────
                Section {
                    LabeledContent("Base URL") {
                        TextField("https://api.cloudflare.com/client/v4", text: $baseURL)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                    }
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("Change only if using a Cloudflare-compatible proxy or test environment.")
                        .font(.caption)
                }

                // ── Error feedback ────────────────────────────────────────
                if let errorMsg = saveError {
                    Section {
                        Text(errorMsg)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }

                // ── Save button ───────────────────────────────────────────
                Section {
                    Button {
                        saveSettings()
                    } label: {
                        HStack {
                            Spacer()
                            if saved {
                                Label("Saved", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Text("Save")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear(perform: loadCurrentValues)
        }
    }

    // MARK: - Helpers

    private func loadCurrentValues() {
        tunnelId  = viewModel.config.tunnelId
        accountId = viewModel.config.accountId
        baseURL   = viewModel.config.baseURL.isEmpty
            ? "https://api.cloudflare.com/client/v4"
            : viewModel.config.baseURL

        // Load token from Keychain (best-effort; blank field if not found)
        apiToken = (try? Storage.loadToken()) ?? ""
    }

    private func saveSettings() {
        saveError = nil
        saved     = false

        // 1. Validate required fields
        guard !tunnelId.isEmpty, !accountId.isEmpty else {
            saveError = "Tunnel ID and Account ID are required."
            return
        }

        // 2. Persist API token to Keychain
        if !apiToken.isEmpty {
            do {
                try Storage.saveToken(apiToken)
            } catch {
                saveError = "Could not save API Token: \(error.localizedDescription)"
                return
            }
        }

        // 3. Persist TunnelConfig to UserDefaults via ViewModel
        viewModel.config.tunnelId  = tunnelId
        viewModel.config.accountId = accountId
        viewModel.config.baseURL   = baseURL.isEmpty
            ? "https://api.cloudflare.com/client/v4"
            : baseURL

        viewModel.saveConfig()

        // 4. Brief "Saved" feedback then dismiss
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    ConfigEditorView()
        .environmentObject(TunnelViewModel())
}
