<?php
declare(strict_types=1);

/**
 * Waitlist SQLite path and PDO handle.
 *
 * Prefers ../private/ (outside the document root) when that directory is writable.
 * Falls back to landing/.data/ on shared hosts where the parent of public_html is not.
 */
function jobsiterecords_db_file(): string
{
    $env = getenv('JOBSITERECORDS_DB');
    if (is_string($env) && $env !== '') {
        return $env;
    }

    $landingDir = dirname(__DIR__);
    $outside    = dirname($landingDir) . '/private/subscribers.sqlite';
    $inside     = $landingDir . '/.data/subscribers.sqlite';

    $outsideDir = dirname($outside);
    if (is_dir($outsideDir) && is_writable($outsideDir)) {
        return $outside;
    }
    if (@mkdir($outsideDir, 0750, true) && is_writable($outsideDir)) {
        return $outside;
    }

    return $inside;
}

function jobsiterecords_open_pdo(): ?PDO
{
    $dbFile = jobsiterecords_db_file();
    $dbDir  = dirname($dbFile);
    if (!is_dir($dbDir)) {
        @mkdir($dbDir, 0750, true);
    }

    try {
        $pdo = new PDO('sqlite:' . $dbFile);
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $pdo->exec("
            CREATE TABLE IF NOT EXISTS subscribers (
                id           INTEGER PRIMARY KEY AUTOINCREMENT,
                email        TEXT    NOT NULL UNIQUE,
                name         TEXT,
                company      TEXT,
                role         TEXT,
                pain_point   TEXT,
                open_to_call INTEGER NOT NULL DEFAULT 0,
                consent      INTEGER NOT NULL DEFAULT 0,
                created_at   TEXT    NOT NULL,
                ip_address   TEXT,
                user_agent   TEXT
            )
        ");
        return $pdo;
    } catch (Throwable $e) {
        error_log('[jobsiterecords] DB init failed: ' . $e->getMessage());
        return null;
    }
}
