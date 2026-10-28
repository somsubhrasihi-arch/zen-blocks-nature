# Build APK from an Android phone with GitHub Actions

1. Extract this ZIP using your phone's Files app. The files inside `zen_blocks_nature/` are the **repository root** contents; do not upload the ZIP itself as a repository file.
2. Create a new GitHub repository called `zen-blocks-nature` with branch `main`.
3. Upload `pubspec.yaml`, `.gitignore`, `lib/main.dart`, `lib/game.dart`, `test/game_test.dart`, and `.github/workflows/build-apk.yml` to the matching paths in the repository. GitHub's mobile website may require **Desktop site** mode or an editor such as github.dev to create nested directories. Make sure the workflow is located at `.github/workflows/build-apk.yml`, not at the repository root.
4. Open the repository's **Actions** tab, select **Build Zen Blocks Android APK**, and tap **Run workflow** (or let the initial push trigger it).
5. When the build finishes successfully, open its run page and download the `ZenBlocks-Nature-Android-APK` artifact. It downloads as a ZIP: extract it to get `app-debug.apk`.
6. Open the APK on your Android phone, allow installation from your browser/files app if prompted, and install.

The GitHub Actions workflow runs Flutter setup, generates Android scaffolding, installs dependencies, executes tests and builds a debug APK. A debug APK is for personal testing, not Play Store publication. The build has not been verified in this environment. If it fails, copy the first error from the Actions build log for troubleshooting.

**Security:** Avoid sharing passwords or access tokens. A public GitHub repository exposes source code. For private repositories, check GitHub Actions usage limits for your account.
