CREATE TABLE IF NOT EXISTS contact_messages (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name varchar(100) NOT NULL,
    email varchar(254) NOT NULL,
    message varchar(2000) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
