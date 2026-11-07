const appVersion = '1.8.0';
const privacyPolicyUrl = 'https://github.com/somsubhrasihi-arch/zen-blocks-nature/blob/main/PRIVACY_POLICY.md';
const supportUrl = 'https://github.com/somsubhrasihi-arch/zen-blocks-nature/issues';

class PolicySection {
  const PolicySection(this.title, this.body);
  final String title, body;
}
const privacySections = [
  PolicySection("About this policy", "T-BLOCK is developed by somsubhrasihi-arch. This policy covers T-BLOCK version 1.8.0, including Classic, Journey, Sprint, Daily Challenge, practice and the earned-coin shop. Last updated: 8 November 2026."),
  PolicySection("Information stored on your device", "The game stores settings, scores, unfinished games, Journey stars, achievements, Sprint records, Daily Challenge history, earned Block Coins and cosmetic ownership on your device. Local recovery copies help restore a damaged save record. Practice does not award coins or replace your saved game."),
  PolicySection("Collection and sharing", "This release does not send your gameplay, scores, coin balance or saved progress to a T-BLOCK server. It includes no account system, advertising, analytics or real-money purchases. Music and sound effects are bundled for offline play. We do not sell your information."),
  PolicySection("Links and support", "Opening the public privacy policy or support page launches your browser. GitHub and your browser handle those visits under their own policies. If you choose to report an issue, the information you submit is handled through GitHub. Public issue reports are visible to others; do not include passwords, payment details or other private information."),
  PolicySection("Retention, backups and deletion", "Local game data stays until you clear app storage or uninstall the game. Recovery copies are stored in the same app storage and are not cloud sync or a backup against uninstalling. Android may back up or restore app data according to your device and Google account settings. Use your Android backup settings to manage those copies. Clearing or uninstalling the app can permanently remove local progress and earned items."),
  PolicySection("Your choices", "You can change audio, vibration, controls and motion settings in the game. You can play without creating an account. To remove local game data, use Android Settings > Apps > T-BLOCK > Storage > Clear storage, or uninstall the app. Check Android backup settings if you also want to remove system-managed backups."),
  PolicySection("Contact and changes", "For support or privacy questions, contact the developer through https://github.com/somsubhrasihi-arch/zen-blocks-nature/issues. This policy will be updated before adding features that change data handling, such as accounts, cloud saves, analytics, ads or payments."),
];
