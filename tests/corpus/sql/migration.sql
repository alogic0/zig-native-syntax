CREATE TABLE audit_log (
  id BIGINT PRIMARY KEY,
  message TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO audit_log (id, message) VALUES (1, 'created');
