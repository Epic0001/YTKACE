import pathlib
import plistlib
import subprocess
import sys
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "Tools" / "sanitize_plist.py"


class SanitizePlistTests(unittest.TestCase):
    def test_removes_only_legacy_icons(self):
        value = {
            "CFBundleIcons": {
                "CFBundleAlternateIcons": {
                    "YTK": {},
                    "YTKPlusDark": {},
                    "YTKiller": {},
                    "YouTubeBlue": {},
                }
            },
            "CFBundleIcons~ipad": {
                "CFBundleAlternateIcons": {
                    "YTKPlus": {},
                    "YouTubeRed": {},
                }
            },
        }
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "Info.plist"
            with path.open("wb") as handle:
                plistlib.dump(value, handle)
            subprocess.run([sys.executable, str(SCRIPT), str(path)], check=True)
            with path.open("rb") as handle:
                result = plistlib.load(handle)

        phone = result["CFBundleIcons"]["CFBundleAlternateIcons"]
        tablet = result["CFBundleIcons~ipad"]["CFBundleAlternateIcons"]
        self.assertEqual(list(phone), ["YouTubeBlue"])
        self.assertEqual(list(tablet), ["YouTubeRed"])
        self.assertTrue(result["UIFileSharingEnabled"])
        self.assertTrue(result["LSSupportsOpeningDocumentsInPlace"])
        self.assertIn("audio", result["UIBackgroundModes"])

    def test_preserves_background_modes(self):
        value = {"UIBackgroundModes": ["fetch"]}
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "Info.plist"
            with path.open("wb") as handle:
                plistlib.dump(value, handle)
            subprocess.run([sys.executable, str(SCRIPT), str(path)], check=True)
            with path.open("rb") as handle:
                result = plistlib.load(handle)
        self.assertEqual(result["UIBackgroundModes"], ["fetch", "audio"])


if __name__ == "__main__":
    unittest.main()
