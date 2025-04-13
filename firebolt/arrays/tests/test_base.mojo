"""Test the base module."""
from testing import assert_true, assert_false, assert_equal
from memory import UnsafePointer, ArcPointer
from firebolt.arrays.base import ArrayData
from firebolt.buffers import Buffer, Bitmap
from firebolt.dtypes import DType, int8


def test_drop_null() -> None:
    """Test the drop null function."""
    var array_len = 6
    var content = UnsafePointer[UInt8].alloc(array_len)
    var buffer = ArcPointer(Buffer(content, array_len))
    buffer[].unsafe_set(0, 1)
    buffer[].unsafe_set(5, 15)
    var buffers = List[ArcPointer[Buffer]]()
    buffers.append(buffer)

    var new_bitmap = Bitmap(UnsafePointer[UInt8].alloc(10), array_len)
    assert_false(new_bitmap.unsafe_get(1))
    new_bitmap.unsafe_set(0, True)
    new_bitmap.unsafe_set(5, True)

    var array = ArrayData(
        int8,
        array_len,
        ArcPointer(new_bitmap^),
        buffers=buffers^,
        children=List[ArcPointer[ArrayData]](),
    )
    # Check the setup.
    assert_true(array.is_valid(0))
    assert_false(array.is_valid(1))

    array.drop_nulls[DType.uint8]()
    var first_buffer = array.buffers[0]
    assert_equal(first_buffer[].unsafe_get(0), 1)
    assert_equal(first_buffer[].unsafe_get(1), 15)
