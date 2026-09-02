import Foundation

@main
enum RedactTests {
    static func main() {
        var failed = 0

        func check(_ name: String, _ condition: @autoclosure () -> Bool) {
            if condition() {
                print("ok   \(name)")
            } else {
                print("FAIL \(name)")
                failed += 1
            }
        }

        check("email", RedactPatterns.containsSecret("mail me at josh@example.com please"))
        check("openai", RedactPatterns.containsSecret("sk-abcdefghijklmnopqrst"))
        check("aws", RedactPatterns.containsSecret("AKIAIOSFODNN7EXAMPLE"))
        check("github", RedactPatterns.containsSecret("ghp_abcdefghijklmnopqrstuvwxyz12"))
        check("slack", RedactPatterns.containsSecret("xoxb-1234567890-token"))
        check("bearer", RedactPatterns.containsSecret("Authorization: Bearer abcdefghijklmnop"))
        check("pem", RedactPatterns.containsSecret("-----BEGIN RSA PRIVATE KEY-----"))
        check("pem-start", RedactPatterns.isPEMStart("-----BEGIN RSA PRIVATE KEY-----"))
        check("pem-end", RedactPatterns.isPEMEnd("-----END RSA PRIVATE KEY-----"))
        check("pem-body", RedactPatterns.looksLikePEMBody("MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSj"))
        check("clean", !RedactPatterns.containsSecret("the login button is offset by 12px"))
        check("merge", RedactPatterns.secretRanges(in: "a@b.co and c@d.co").count == 2)

        if failed > 0 {
            print("\(failed) failed")
            exit(1)
        }
        print("all passed")
    }
}
