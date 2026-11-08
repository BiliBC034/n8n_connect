# Security policy

## Supported versions

Only the `main` branch is maintained. Security fixes are published there; there are no maintenance branches for earlier versions.

## How to report a vulnerability

**Do not open a public issue** to report a vulnerability.

Use GitHub's private reporting feature:

1. Go to the **Security** tab of the repository.
2. Click **Report a vulnerability**.
3. Describe the problem, the steps to reproduce it and the impact it would have.

If the **Report a vulnerability** button does not appear, open an issue **without any details** of the vulnerability, only to ask for a private contact channel.

We will try to respond within a reasonable time and coordinate the fix before making the information public.

## Scope

The following are in scope, among others:

- **Session and JWT**: issuance, validation, expiry and renewal of the session with the server.
- **Execution of actions received by push**: any way in which a message from n8n could trigger actions on the phone without the proper confirmation or permission.
- **Credential storage on the phone**: the session is stored in encrypted storage; any leak of tokens or secrets outside it is a problem.
- **n8n templates**: example flows or templates that expose data or actions insecurely.

Out of scope are problems that depend on an n8n server misconfigured by its owner (for example, a webhook without authentication that the user has disabled) and failures in third-party software, which must be reported to their authors.

## Security model (summary)

The full model is in [docs/PROTOCOL.md, section 2](docs/PROTOCOL.md#2-security). In short:

- **HTTPS only**: the app does not accept `http://` servers and does not allow cleartext traffic.
- **Session exchange**: the app obtains a Firebase token and the server exchanges it for a short-lived JWT (12 h). App webhooks must require that JWT (the templates do).
- **Automatic renewal**: the app requests a new JWT before the current one expires and, if the server rejects the session, renews it once.
- **Storage**: the session is kept in encrypted storage backed by the Android Keystore. The offline copy, the inbox and the automation permissions are stored unencrypted and never contain the JWT or the Firebase token.
- **Same origin**: a spec cannot send the JWT to another domain; absolute submit URLs must be HTTPS and use the same host and port as the server.
- **Revocation**: access is removed by disabling the user on the server, and JWTs already issued are invalidated by rotating the secret of the JWT credential.
- **Server-side validation**: the required fields of a spec are only for the interface; the server must always validate what it receives.

## Best practices for contributing

- Do not commit keys, tokens, `google-services.json`, signing keys (`*.jks`, `*.keystore`) or personal data.
- If a secret is pushed by mistake, revoke it first and then clean the history.
