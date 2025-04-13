from .primitive import *
from ..buffers import Buffer, Bitmap
from sys.info import sizeof


trait Array(Movable, Sized):
    fn as_data(self) -> ArrayData:
        ...


@value
struct ArrayData(Movable):
    var dtype: DataType
    var length: Int
    var bitmap: ArcPointer[Bitmap]
    var buffers: List[ArcPointer[Buffer]]
    var children: List[ArcPointer[ArrayData]]

    fn is_valid(self, index: Int) -> Bool:
        return self.bitmap[].unsafe_get(index)

    fn as_primitive[T: DataType](self) raises -> PrimitiveArray[T]:
        return PrimitiveArray[T](self)

    fn as_int8(self) raises -> Int8Array:
        return Int8Array(self)

    fn as_int16(self) raises -> Int16Array:
        return Int16Array(self)

    fn as_int32(self) raises -> Int32Array:
        return Int32Array(self)

    fn as_int64(self) raises -> Int64Array:
        return Int64Array(self)

    fn as_uint8(self) raises -> UInt8Array:
        return UInt8Array(self)

    fn as_uint16(self) raises -> UInt16Array:
        return UInt16Array(self)

    fn as_uint32(self) raises -> UInt32Array:
        return UInt32Array(self)

    fn as_uint64(self) raises -> UInt64Array:
        return UInt64Array(self)

    fn as_float32(self) raises -> Float32Array:
        return Float32Array(self)

    fn as_float64(self) raises -> Float64Array:
        return Float64Array(self)

    fn as_string(self) raises -> StringArray:
        return StringArray(self)

    fn as_list(self) raises -> ListArray:
        return ListArray(self)

    fn _drop_nulls[
        T: DType
    ](
        mut self, buffer: ArcPointer[Buffer], buffer_start: Int, buffer_end: Int
    ) -> None:
        """Drop nulls from the Array.

        The approach is the following:
           - find a run of nulls
           - find the run of valid entries after the run of nulls
           - move the valid entries to overwrite the run of nulls
           - repeat
        """
        var start = buffer_start
        while start < buffer_end:
            if self.bitmap[].unsafe_get(start):
                print("Skipping valid value at ", start)
                start += 1
                continue

            # Find the end of the run of nulls, could be just one null.
            var end_nulls = start
            while start < buffer_end and not self.bitmap[].unsafe_get(
                end_nulls
            ):
                end_nulls += 1

            # Find the end of the run of values.
            var end_values = end_nulls
            while end_nulls < buffer_end and self.bitmap[].unsafe_get(
                end_values
            ):
                end_values += 1
            values_len = end_values - end_nulls

            # Compact the data.
            memcpy(
                buffer[].offset(start),
                buffer[].offset(end_nulls),
                values_len * sizeof[T](),
            )
            # Adjust the bitmp
            for i in range(start, end_values):
                self.bitmap[].unsafe_set(i, (i - start) < values_len)

            # Get ready for next iteration.
            start += values_len

    fn drop_nulls[T: DType](mut self) -> None:
        """Drops null values from the Array.

        Currently we drop nulls from individual buffers, we do not delete buffers.
        """
        # Track the start position in the validity bitmap.
        var buffer_start = 0
        for buffer_index in range(len(self.buffers)):
            var buffer = self.buffers[buffer_index]
            buffer_end = buffer_start + buffer[].length[T]()
            self._drop_nulls[T](buffer, buffer_start, buffer_end)
            buffer_start = buffer_end
