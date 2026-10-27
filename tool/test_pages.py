"""Exercise Pages preparation without deploying or changing DNS."""
import tempfile
import unittest
from pathlib import Path
from prepare_pages import prepare


class PagesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'web').mkdir()
        (self.root / 'build/web').mkdir(parents=True)
        (self.root / 'build/web/main.dart.js').write_text('// fixture')

    def test_custom_domain_and_nojekyll(self):
        (self.root / 'web/CNAME').write_text('app.uslinkyou.com\n')
        prepare(self.root)
        self.assertEqual((self.root / 'build/web/CNAME').read_text(), 'app.uslinkyou.com\n')
        self.assertTrue((self.root / 'build/web/.nojekyll').exists())
        prepare(self.root)
        self.assertEqual((self.root / 'build/web/CNAME').read_text(), 'app.uslinkyou.com\n')

    def test_no_custom_domain_removes_stale_deploy_file(self):
        (self.root / 'build/web/CNAME').write_text('old.example.com')
        prepare(self.root)
        self.assertFalse((self.root / 'build/web/CNAME').exists())

    def test_url_is_rejected(self):
        (self.root / 'web/CNAME').write_text('https://app.uslinkyou.com/')
        with self.assertRaises(ValueError):
            prepare(self.root)

    def test_missing_flutter_build_fails(self):
        (self.root / 'build/web/main.dart.js').unlink()
        with self.assertRaises(ValueError):
            prepare(self.root)


if __name__ == '__main__':
    unittest.main()
