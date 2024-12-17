import importlib.resources

from unlzw3 import unlzw, unlzw_fast


def test_simple():

    with importlib.resources.path("unlzw3.tests", "hello.Z") as fn:
        assert unlzw(fn) == b"He110\n"

def test_simple_fast():

    with importlib.resources.path("unlzw3.tests", "hello.Z") as fn:
        assert unlzw_fast(fn) == b"He110\n"
        assert unlzw_fast(fn) == unlzw(fn)


def test_lipsum():
    """
    courtesy lipsum.com
    """

    with importlib.resources.path("unlzw3.tests", "lipsum.com.Z") as fn:
        data = unlzw(fn)

        assert data == unlzw(fn.read_bytes())
        assert len(data) == 100172

def test_lipsum_fast():
    """
    courtesy lipsum.com
    """

    with importlib.resources.path("unlzw3.tests", "lipsum.com.Z") as fn:
        data = unlzw_fast(fn)
        data_slow = unlzw(fn)

        assert data == unlzw_fast(fn.read_bytes())
        assert len(data) == 100172
        assert data == data_slow


