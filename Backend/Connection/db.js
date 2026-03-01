const { Client } = require('pg');
require('dotenv').config();

const {
  DB_USER,
  DB_PASSWORD,
  DB_HOST,
  DB_PORT,
  DB_NAME
} = process.env;

async function createDatabaseIfNotExists() {
  const client = new Client({
    user: DB_USER,
    host: DB_HOST,
    password: DB_PASSWORD,
    port: DB_PORT,
    database: 'postgres' 
  });

  await client.connect();

  const res = await client.query(
    `SELECT 1 FROM pg_database WHERE datname = $1`,
    [DB_NAME]
  );

  if (res.rowCount === 0) {
    console.log('Database not found. Creating...');
    await client.query(`CREATE DATABASE ${DB_NAME}`);
    console.log('Database created.');
  } else {
    console.log('Database already exists.');
  }

  await client.end();
}

module.exports = createDatabaseIfNotExists;