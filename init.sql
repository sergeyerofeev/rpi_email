CREATE TABLE
    email_data (
        id SERIAL PRIMARY KEY,
        email VARCHAR(320) NOT NULL,
        name_email VARCHAR,
        delivery_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
    );