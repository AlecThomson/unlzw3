from setuptools import setup
from Cython.Build import cythonize
from Cython.Compiler import Options

Options.docstrings = True


setup(
    ext_modules=cythonize(
        "src/unlzw3/unlzw.pyx", compiler_directives={"language_level": "3"}
    )
)
