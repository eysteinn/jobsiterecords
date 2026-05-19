<?php
declare(strict_types=1);

/**
 * jobsiterecords.com — subscriber CSV export.
 *
 * Usage:
 *   1. Set JOBSITERECORDS_EXPORT_PASSWORD in your web server env (NOT in this file).
 *   2. Visit /export.php?password=YOUR_PASSWORD
 *
 * After you've grabbed the CSV, consider deleting this file from the server.
 * Treat the password as throwaway: rotate it every time you export.
 */

$password = getenv('JOBSITERECORDS_EXPORT_PASSWORD') ?: '';
$provided = (string)($_GET['password'] ?? '');

if ($password === '' || $password === 'change-me') {
    http_response_code(500);
    header('Content-Type: text/plain; charset=utf-8');
    echo "Export disabled: set JOBSITERECORDS_EXPORT_PASSWORD in the server environment.\n";
    exit;
}

if (!hash_equals($password, $provided)) {
    http_response_code(403);
    header('Content-Type: text/plain; charset=utf-8');
    echo "Forbidden\n";
    exit;
}

require_once __DIR__ . '/lib/db.php';

$dbFile = jobsiterecords_db_file();

if (!is_file($dbFile)) {
    http_response_code(404);
    header('Content-Type: text/plain; charset=utf-8');
    echo "No database yet — nobody has signed up.\n";
    exit;
}

try {
    $pdo = jobsiterecords_open_pdo();
    if ($pdo === null) {
        throw new RuntimeException('open failed');
    }
} catch (Throwable $e) {
    http_response_code(500);
    header('Content-Type: text/plain; charset=utf-8');
    echo "DB open failed.\n";
    error_log('[jobsiterecords export] DB open failed: ' . $e->getMessage());
    exit;
}

$filename = 'jobsiterecords-subscribers-' . gmdate('Ymd-His') . '.csv';

header('Content-Type: text/csv; charset=utf-8');
header('Content-Disposition: attachment; filename="' . $filename . '"');
header('Cache-Control: no-store');

$out = fopen('php://output', 'w');

// Excel-friendly UTF-8 BOM.
fwrite($out, "\xEF\xBB\xBF");

fputcsv($out, [
    'id',
    'email',
    'name',
    'company',
    'role',
    'pain_point',
    'open_to_call',
    'consent',
    'created_at',
    'ip_address',
    'user_agent',
]);

$stmt = $pdo->query("
    SELECT id, email, name, company, role, pain_point,
           open_to_call, consent, created_at, ip_address, user_agent
    FROM subscribers
    ORDER BY created_at DESC
");

foreach ($stmt as $row) {
    fputcsv($out, $row);
}

fclose($out);
