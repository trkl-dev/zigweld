import unittest

from fib import add, sub, uses_private, echo


class TestStringMethods(unittest.TestCase):

    def test_add(self):
        self.assertEqual(add(12, 18), 30)

    def test_sub(self):
        self.assertEqual(sub(12, 18), -6)

    def test_private_not_available(self):
        def try_import_private_func():
            from fib import private

        self.assertRaises(ImportError, try_import_private_func)

    def test_public_func_with_private_dependency(self):
        self.assertEqual(uses_private(10), 12)

    def test_echo(self):
        self.assertEqual(echo("hi there\n"), "hi there\n")


if __name__ == '__main__':
    _ = unittest.main()
