import pyarrow as pa

# Create a new field named "number" of type int64 that is not nullable.
number_field = pa.field('number', pa.int64(), nullable=True)

# Create a list of fields for pa.schema()
schema_fields = [number_field]

# Create a new schema from the fields.
schema = pa.schema(schema_fields)

# Construct some metadata to explain Fletchgen that it
# should allow the FPGA kernel to read from this schema.
metadata = {b'fletcher_mode': b'read',
            b'fletcher_name': b'ExampleBatch'}

# Add the metadata to the schema
schema = schema.add_metadata(metadata)

# Create a list of PyArrow Arrays. Every Array can be seen
# as a 'Column' of the RecordBatch we will create.
data = [pa.array([1, -3, 3, -7])]

# Create a RecordBatch from the Arrays.
recordbatch = pa.RecordBatch.from_arrays(data, schema)

# Create an Arrow RecordBatchFileWriter.
writer = pa.RecordBatchFileWriter('recordbatch.rb', schema)

# Write the RecordBatch.
writer.write(recordbatch)

# Close the writer.
writer.close()
