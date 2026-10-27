-- Create a storage integration with S3 and IAM role
CREATE OR REPLACE STORAGE INTEGRATION ticketing_int
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'S3'
    ENABLED = TRUE
    STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::xxxxxxxxxxxx:role/snowflakerole'
    STORAGE_ALLOWED_LOCATIONS = ('s3://event-ticketing-sf-dbt/');

-- Describe storage integration
DESC INTEGRATION ticketing_int; 

-- Create the parquet file format
CREATE OR REPLACE FILE FORMAT parquet_format
TYPE = 'PARQUET';

-- List file formats
SHOW FILE FORMATS;

-- Create an external S3 stage
CREATE OR REPLACE STAGE ticketing_stage
    STORAGE_INTEGRATION = ticketing_int
    URL = 's3://event-ticketing-sf-dbt/'
    FILE_FORMAT = PARQUET_FORMAT;

LIST @ticketing_stage;
