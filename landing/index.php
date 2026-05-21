<?php
declare(strict_types=1);

/**
 * jobsiterecords.com: early-access landing page.
 *
 * - Renders the marketing page and the waitlist form.
 * - On POST, validates input and stores a row in a SQLite database.
 * - Database path: see lib/db.php (../private/ when writable, else landing/.data/).
 *   Override with JOBSITERECORDS_DB. Direct .sqlite downloads are blocked in .htaccess.
 */

require_once __DIR__ . '/lib/db.php';

$pdo = jobsiterecords_open_pdo();

$message = '';
$error   = '';

// Preserve user input on validation errors so they don't lose their typing.
$old = [
    'email'        => '',
    'name'         => '',
    'company'      => '',
    'role'         => '',
    'pain_point'   => '',
    'open_to_call' => '',
];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $old['email']        = trim((string)($_POST['email']        ?? ''));
    $old['name']         = trim((string)($_POST['name']         ?? ''));
    $old['company']      = trim((string)($_POST['company']      ?? ''));
    $old['role']         = trim((string)($_POST['role']         ?? ''));
    $old['pain_point']   = trim((string)($_POST['pain_point']   ?? ''));
    $old['open_to_call'] = trim((string)($_POST['open_to_call'] ?? ''));

    $consent     = isset($_POST['consent']) ? 1 : 0;
    $openToCall  = $old['open_to_call'] === 'yes' ? 1 : 0;
    $honeypot    = trim((string)($_POST['website'] ?? ''));

    if ($honeypot !== '') {
        // Looks like a bot. Pretend it worked so we don't help them debug.
        $message = "Thanks, you're on the list.";
    } elseif (!filter_var($old['email'], FILTER_VALIDATE_EMAIL)) {
        $error = 'Please enter a valid email address.';
    } elseif ($consent !== 1) {
        $error = 'Please tick the box to confirm you want to receive updates.';
    } elseif ($pdo === null) {
        $error = 'Something went wrong on our side. Please try again in a minute.';
    } else {
        try {
            $stmt = $pdo->prepare("
                INSERT INTO subscribers
                  (email, name, company, role, pain_point, open_to_call,
                   consent, created_at, ip_address, user_agent)
                VALUES
                  (:email, :name, :company, :role, :pain_point, :open_to_call,
                   :consent, :created_at, :ip_address, :user_agent)
            ");
            $stmt->execute([
                ':email'        => strtolower($old['email']),
                ':name'         => $old['name']    !== '' ? $old['name']    : null,
                ':company'      => $old['company'] !== '' ? $old['company'] : null,
                ':role'         => $old['role']    !== '' ? $old['role']    : null,
                ':pain_point'   => $old['pain_point'] !== '' ? $old['pain_point'] : null,
                ':open_to_call' => $openToCall,
                ':consent'      => $consent,
                ':created_at'   => gmdate('c'),
                ':ip_address'   => $_SERVER['REMOTE_ADDR']    ?? null,
                ':user_agent'   => substr((string)($_SERVER['HTTP_USER_AGENT'] ?? ''), 0, 500),
            ]);
            $message = "Thanks. You're on the Job Site Records early-access list. We'll be in touch.";
            $old = array_fill_keys(array_keys($old), '');
        } catch (PDOException $e) {
            // SQLSTATE 23000 = integrity constraint (the UNIQUE email index).
            if ($e->getCode() === '23000') {
                $message = "You're already on the list. Thanks.";
                $old = array_fill_keys(array_keys($old), '');
            } else {
                error_log('[jobsiterecords] insert failed: ' . $e->getMessage());
                $error = 'Something went wrong saving your details. Please try again.';
            }
        }
    }
}

function h(?string $s): string {
    return htmlspecialchars((string)$s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>Job Site Records: document the job. Share the proof.</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="description" content="Photos, voice notes, and tags as you work. Export a zip with everything. It stays on your phone, no account required. Request early access at jobsiterecords.com.">
    <meta name="robots" content="index,follow">
    <meta property="og:title" content="Job Site Records: document the job. Share the proof.">
    <meta property="og:description" content="Local field notes for contractors. Photos, voice notes, tags. Free. Local. Private. jobsiterecords.com">
    <meta property="og:type" content="website">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
    <style>
        :root {
            --cream:        #f8f3e6;
            --cream-2:      #efe7d2;
            --cream-card:   #ffffff;
            --ink:          #14110d;
            --ink-soft:     #3d3830;
            --ink-mute:     #807a6e;
            --line:         #e6dcc4;
            --line-2:       #d8ccb0;
            --yellow:       #f5c518;
            --yellow-hover: #e0b200;
            --yellow-soft:  #fdecb0;
            --tag-before:   #fde6c4;
            --tag-before-ink:#7c4a00;
            --tag-issue:    #ffc8b8;
            --tag-issue-ink:#8a3214;
            --tag-after:    #c8e0c0;
            --tag-after-ink:#22591f;
            --shadow:       0 6px 24px rgba(20, 17, 13, 0.08);
            --shadow-lg:    0 24px 60px rgba(20, 17, 13, 0.16);
            --shadow-phone: 0 30px 80px rgba(20, 17, 13, 0.22), 0 0 0 1px rgba(255,255,255,0.04) inset;
            --radius:       18px;
            --radius-sm:    12px;
            --ok-bg:        #dcfce7;
            --ok-ink:       #166534;
            --err-bg:       #fee2e2;
            --err-ink:      #991b1b;
        }
        *, *::before, *::after { box-sizing: border-box; }
        html { scroll-behavior: smooth; }
        body {
            margin: 0;
            font-family: "Inter", system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
            background: var(--cream);
            color: var(--ink);
            line-height: 1.55;
            font-size: 17px;
            -webkit-font-smoothing: antialiased;
            text-rendering: optimizeLegibility;
        }
        a { color: var(--ink); text-decoration: none; font-weight: 500; }
        a:hover { color: var(--yellow-hover); }

        .wrap { max-width: 1180px; margin: 0 auto; padding: 0 24px; }

        /* Top bar */
        .top {
            position: sticky;
            top: 0;
            z-index: 50;
            background: rgba(248, 243, 230, 0.9);
            backdrop-filter: blur(10px);
            border-bottom: 1px solid rgba(20, 17, 13, 0.06);
        }
        .top-inner {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 18px;
            padding: 16px 0;
            flex-wrap: wrap;
        }
        .logo {
            display: flex;
            align-items: center;
            gap: 12px;
        }
        .logo-mark {
            width: 44px; height: 44px;
            border-radius: 11px;
            background: var(--yellow);
            display: grid;
            place-items: center;
            color: var(--ink);
            flex-shrink: 0;
        }
        .logo-text strong {
            display: block;
            font-size: 1.05rem;
            font-weight: 800;
            line-height: 1.1;
            letter-spacing: -0.01em;
        }
        .logo-text span {
            font-size: 0.78rem;
            color: var(--ink-mute);
            font-weight: 500;
        }
        .top-nav {
            display: flex;
            align-items: center;
            gap: 28px;
            flex-wrap: wrap;
        }
        .top-nav a {
            font-size: 0.95rem;
            color: var(--ink-soft);
            font-weight: 600;
        }
        .top-nav a:hover { color: var(--yellow-hover); }
        .top-right {
            display: flex;
            align-items: center;
            gap: 18px;
            flex-wrap: wrap;
        }
        .top-domain {
            font-size: 0.9rem;
            color: var(--ink-mute);
            font-weight: 500;
        }
        .btn {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            padding: 12px 22px;
            border-radius: 999px;
            font-weight: 700;
            font-size: 0.95rem;
            font-family: inherit;
            border: none;
            cursor: pointer;
            text-decoration: none;
            transition: transform 0.12s ease, background 0.12s ease, color 0.12s ease;
            line-height: 1;
        }
        .btn-primary {
            background: var(--yellow);
            color: var(--ink);
        }
        .btn-primary:hover { background: var(--yellow-hover); color: var(--ink); transform: translateY(-1px); }
        .btn-ghost {
            background: transparent;
            color: var(--ink);
            border: none;
            padding: 12px 8px;
        }
        .btn-ghost:hover { color: var(--yellow-hover); }
        .btn .play-circle {
            width: 28px; height: 28px;
            border-radius: 50%;
            border: 2px solid var(--ink);
            display: inline-grid;
            place-items: center;
        }
        .btn-ghost:hover .play-circle { border-color: var(--yellow-hover); }

        /* Hero */
        .hero {
            padding: 56px 0 48px;
            position: relative;
            overflow: hidden;
        }
        .hero::before {
            content: "";
            position: absolute;
            inset: -40% -20% auto -20%;
            height: 110%;
            background:
                radial-gradient(ellipse 55% 40% at 80% 5%, rgba(245, 197, 24, 0.18), transparent 55%),
                radial-gradient(ellipse 30% 28% at 10% 25%, rgba(245, 197, 24, 0.10), transparent 60%);
            pointer-events: none;
        }
        .hero-grid {
            position: relative;
            display: grid;
            grid-template-columns: 1fr;
            gap: 48px;
            align-items: center;
        }
        @media (min-width: 960px) {
            .hero-grid { grid-template-columns: minmax(0, 1.05fr) minmax(0, 0.95fr); gap: 56px; }
        }
        .hero h1 {
            font-family: "Inter", system-ui, sans-serif;
            font-weight: 900;
            font-size: clamp(2.4rem, 6vw, 4.6rem);
            line-height: 0.98;
            letter-spacing: -0.04em;
            margin: 0 0 22px;
            color: var(--ink);
        }
        .hero h1 .line { display: block; }
        .hero .sub {
            font-size: clamp(1.05rem, 1.4vw, 1.2rem);
            color: var(--ink-soft);
            max-width: 30em;
            margin: 0 0 16px;
            line-height: 1.55;
        }
        .hero-audience {
            font-size: clamp(0.98rem, 1.2vw, 1.08rem);
            color: var(--ink-mute);
            max-width: 36em;
            margin: 0 0 28px;
            line-height: 1.5;
        }
        .hero-cta {
            display: flex;
            flex-wrap: wrap;
            align-items: center;
            gap: 18px;
            margin-bottom: 18px;
        }
        .hero-note {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            font-size: 0.92rem;
            color: var(--ink-mute);
            margin: 0 0 44px;
            font-weight: 500;
        }
        .hero-note svg { color: var(--ink-mute); }

        /* Feature strip */
        .features {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 28px 36px;
            max-width: 560px;
        }
        @media (min-width: 540px) {
            .features { grid-template-columns: repeat(4, 1fr); gap: 16px; }
        }
        .feature {
            text-align: left;
        }
        .feature-ico {
            display: inline-grid;
            place-items: center;
            width: 44px; height: 44px;
            border-radius: 12px;
            background: var(--yellow-soft);
            color: var(--ink);
            margin-bottom: 10px;
        }
        .feature strong {
            display: block;
            font-size: 0.95rem;
            font-weight: 800;
            margin-bottom: 4px;
            letter-spacing: -0.01em;
        }
        .feature span {
            display: block;
            font-size: 0.8rem;
            color: var(--ink-mute);
            line-height: 1.45;
        }

        .validation-note {
            margin-top: 36px;
            padding: 18px 22px;
            background: var(--cream-card);
            border: 1px solid var(--line);
            border-radius: var(--radius-sm);
            font-size: 0.92rem;
            color: var(--ink-soft);
            box-shadow: var(--shadow);
            max-width: 560px;
            line-height: 1.55;
        }
        .validation-note strong { color: var(--ink); }

        /* Phone mock */
        .phone-wrap {
            display: flex;
            justify-content: center;
            position: relative;
        }
        .phone {
            width: min(340px, 100%);
            background: linear-gradient(160deg, #2a2a2a 0%, #0f0f0f 100%);
            padding: 12px;
            border-radius: 46px;
            box-shadow: var(--shadow-phone);
            position: relative;
        }
        .phone::before {
            content: "";
            position: absolute;
            top: 14px; left: 50%;
            transform: translateX(-50%);
            width: 110px; height: 28px;
            background: #0a0a0a;
            border-radius: 999px;
            z-index: 3;
        }
        .phone-inner {
            background: var(--cream);
            border-radius: 36px;
            overflow: hidden;
            min-height: 600px;
        }
        .status-bar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 14px 28px 6px;
            font-size: 0.78rem;
            font-weight: 700;
            color: var(--ink);
        }
        .status-bar .icons { display: inline-flex; gap: 5px; align-items: center; }
        .app-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 14px 18px 12px;
        }
        .app-header svg { color: var(--ink-soft); }
        .app-title {
            font-weight: 800;
            font-size: 0.95rem;
            letter-spacing: -0.01em;
        }
        .segmented {
            display: flex;
            gap: 6px;
            margin: 0 18px 16px;
            background: rgba(20, 17, 13, 0.05);
            border-radius: 999px;
            padding: 4px;
            font-size: 0.78rem;
            font-weight: 700;
        }
        .segmented div {
            flex: 1;
            text-align: center;
            padding: 8px 0;
            border-radius: 999px;
            color: var(--ink-mute);
        }
        .segmented div.active {
            background: var(--yellow);
            color: var(--ink);
        }
        .section-label {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 6px 18px 10px;
        }
        .section-label strong {
            font-size: 0.85rem;
            font-weight: 800;
            letter-spacing: -0.01em;
        }
        .add-pill {
            width: 26px; height: 26px;
            border-radius: 50%;
            background: var(--yellow);
            display: grid;
            place-items: center;
            color: var(--ink);
            font-weight: 800;
            font-size: 1rem;
            line-height: 1;
        }
        .job-card {
            display: flex;
            gap: 12px;
            padding: 10px 12px;
            margin: 0 14px 8px;
            background: var(--cream-card);
            border: 1px solid var(--line);
            border-radius: 14px;
        }
        .job-thumb {
            width: 48px; height: 48px;
            border-radius: 10px;
            flex-shrink: 0;
            background: linear-gradient(135deg, #d4c08a, #9a7d4a);
        }
        .job-thumb.green { background: linear-gradient(135deg, #b6c7a0, #6e8a52); }
        .job-thumb.brown { background: linear-gradient(135deg, #c8a070, #7d5430); }
        .job-meta { flex: 1; min-width: 0; }
        .job-meta-top {
            display: flex;
            justify-content: space-between;
            align-items: baseline;
        }
        .job-name {
            font-size: 0.82rem;
            font-weight: 800;
            letter-spacing: -0.01em;
        }
        .job-count {
            font-size: 0.7rem;
            color: var(--ink-mute);
            font-weight: 600;
        }
        .job-sub {
            font-size: 0.72rem;
            color: var(--ink-soft);
        }
        .job-date {
            font-size: 0.66rem;
            color: var(--ink-mute);
        }
        .timeline-head {
            font-size: 0.85rem;
            font-weight: 800;
            padding: 14px 18px 6px;
            letter-spacing: -0.01em;
        }
        .timeline-row {
            padding: 0 18px 14px;
        }
        .timeline-meta {
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: 0.7rem;
            color: var(--ink-soft);
            margin-bottom: 8px;
        }
        .timeline-dot {
            width: 8px; height: 8px;
            border-radius: 50%;
            background: var(--yellow);
        }
        .tag-strip {
            display: flex;
            gap: 6px;
            margin-bottom: 8px;
            flex-wrap: wrap;
        }
        .tag {
            font-size: 0.62rem;
            font-weight: 800;
            padding: 4px 10px;
            border-radius: 999px;
            letter-spacing: 0.02em;
        }
        .tag.before { background: var(--tag-before); color: var(--tag-before-ink); }
        .tag.issue  { background: var(--tag-issue);  color: var(--tag-issue-ink); }
        .tag.after  { background: var(--tag-after);  color: var(--tag-after-ink); }
        .photo-strip {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 6px;
            margin-bottom: 10px;
        }
        .photo {
            aspect-ratio: 1 / 1;
            border-radius: 8px;
            background: linear-gradient(135deg, #b8a888, #6d5a3d);
        }
        .photo.b { background: linear-gradient(135deg, #8a6a44, #4a2f15); }
        .photo.c { background: linear-gradient(135deg, #c8b88a, #8a7a50); }
        .waveform {
            display: flex;
            align-items: center;
            gap: 10px;
            background: var(--cream-card);
            border: 1px solid var(--line);
            border-radius: 12px;
            padding: 8px 12px;
        }
        .wave-play {
            width: 24px; height: 24px;
            border-radius: 50%;
            background: var(--ink);
            color: var(--cream);
            display: grid;
            place-items: center;
            flex-shrink: 0;
        }
        .wave-bars {
            display: flex;
            align-items: center;
            gap: 2px;
            flex: 1;
            height: 22px;
        }
        .wave-bars span {
            display: block;
            width: 2px;
            background: var(--ink);
            border-radius: 2px;
            opacity: 0.4;
        }
        .wave-time { font-size: 0.7rem; font-weight: 700; color: var(--ink-soft); }

        /* Sections */
        section { padding: 80px 0; }
        section.tint { background: var(--cream-2); border-top: 1px solid var(--line); border-bottom: 1px solid var(--line); }
        .section-head { max-width: 680px; margin-bottom: 44px; }
        .eyebrow {
            display: inline-block;
            font-size: 0.78rem;
            font-weight: 800;
            letter-spacing: 0.12em;
            text-transform: uppercase;
            color: var(--yellow-hover);
            margin-bottom: 14px;
        }
        .section-head h2 {
            font-size: clamp(1.8rem, 3.5vw, 2.6rem);
            line-height: 1.05;
            letter-spacing: -0.03em;
            font-weight: 800;
            margin: 0 0 14px;
        }
        .section-lead {
            font-size: 1.05rem;
            color: var(--ink-soft);
            margin: 0;
        }

        /* Use-case grid */
        .grid {
            display: grid;
            gap: 18px;
            grid-template-columns: 1fr;
        }
        @media (min-width: 640px) { .grid.cols-2 { grid-template-columns: repeat(2, 1fr); } }
        @media (min-width: 960px) { .grid.cols-3 { grid-template-columns: repeat(3, 1fr); } }

        .tile {
            background: var(--cream-card);
            border: 1px solid var(--line);
            border-radius: var(--radius-sm);
            padding: 26px;
            box-shadow: var(--shadow);
        }
        .tile .tile-ico {
            width: 40px; height: 40px;
            border-radius: 10px;
            background: var(--yellow-soft);
            display: grid;
            place-items: center;
            margin-bottom: 14px;
            color: var(--ink);
        }
        .tile h3 {
            margin: 0 0 8px;
            font-size: 1.08rem;
            font-weight: 800;
            letter-spacing: -0.01em;
        }
        .tile p {
            margin: 0;
            font-size: 0.95rem;
            color: var(--ink-soft);
        }

        /* How-it-works steps */
        .steps {
            margin: 0; padding: 0; list-style: none;
            counter-reset: step;
        }
        .steps li {
            position: relative;
            padding-left: 64px;
            margin-bottom: 32px;
        }
        .steps li::before {
            counter-increment: step;
            content: counter(step);
            position: absolute;
            left: 0; top: 0;
            width: 44px; height: 44px;
            border-radius: 12px;
            background: var(--yellow);
            color: var(--ink);
            font-weight: 900;
            font-size: 1.1rem;
            display: grid;
            place-items: center;
        }
        .steps strong { display: block; font-size: 1.1rem; margin-bottom: 6px; letter-spacing: -0.01em; }
        .steps span { font-size: 0.97rem; color: var(--ink-soft); }
        .split { display: grid; gap: 56px; align-items: center; }
        @media (min-width: 900px) { .split { grid-template-columns: 1fr 360px; } }

        /* Export pre */
        .two-col { display: grid; gap: 28px; }
        @media (min-width: 820px) { .two-col { grid-template-columns: 1fr 1fr; } }

        .dashboard-body {
            display: grid;
            gap: 32px;
            align-items: start;
        }
        @media (min-width: 1040px) {
            .dashboard-body { grid-template-columns: minmax(0, 1fr) minmax(0, 1.15fr); gap: 40px; }
        }
        @media (max-width: 1039px) {
            .dashboard-body { grid-template-columns: 1fr; }
            .dashboard-figure { order: -1; }
        }
        .dashboard-copy p { margin: 0 0 14px; color: var(--ink-soft); font-size: 1.02rem; }
        .dashboard-copy ul { margin: 0 0 14px; padding-left: 1.2em; color: var(--ink-soft); line-height: 1.65; }
        .dashboard-copy li { margin-bottom: 6px; }
        .dashboard-figure { margin: 0; padding: 0; }
        .dashboard-figure img {
            display: block;
            width: 100%;
            height: auto;
            border-radius: var(--radius-sm);
            border: 1px solid var(--line);
            box-shadow: var(--shadow-lg);
            background: var(--cream-card);
        }
        .dashboard-figcaption {
            margin-top: 12px;
            font-size: 0.85rem;
            color: var(--ink-mute);
            line-height: 1.45;
        }
        .export-box {
            background: var(--cream-card);
            border: 1px solid var(--line);
            border-radius: var(--radius-sm);
            padding: 24px;
            box-shadow: var(--shadow);
            font-family: ui-monospace, "Cascadia Code", "Source Code Pro", monospace;
            font-size: 0.82rem;
            line-height: 1.55;
            color: var(--ink-soft);
            overflow-x: auto;
            white-space: pre;
        }
        .export-box .k { color: var(--yellow-hover); font-weight: 700; }

        /* FAQ */
        details {
            background: var(--cream-card);
            border: 1px solid var(--line);
            border-radius: var(--radius-sm);
            margin-bottom: 12px;
            box-shadow: var(--shadow);
        }
        details summary {
            list-style: none;
            cursor: pointer;
            padding: 20px 22px;
            font-weight: 700;
            font-size: 1rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 16px;
        }
        details summary::-webkit-details-marker { display: none; }
        details summary::after {
            content: "+";
            font-size: 1.4rem;
            font-weight: 400;
            color: var(--yellow-hover);
            line-height: 1;
        }
        details[open] summary::after { content: "−"; }
        details .faq-a {
            padding: 0 22px 20px;
            margin: 0;
            font-size: 0.97rem;
            color: var(--ink-soft);
        }

        /* Form */
        #waitlist,
        #teams,
        #dashboard,
        #customers,
        #simple { scroll-margin-top: 90px; }

        .simple-list {
            margin: 0;
            padding-left: 1.2em;
            color: var(--ink-soft);
            line-height: 1.7;
            font-size: 1rem;
            max-width: 720px;
        }
        .simple-list li { margin-bottom: 6px; }
        .simple-list li strong { color: var(--ink); }
        .form-section {
            background: var(--cream-card);
            border: 1px solid var(--line);
            border-radius: var(--radius);
            padding: 36px 32px;
            box-shadow: var(--shadow-lg);
        }
        .form-section h2 {
            margin: 0 0 8px;
            font-size: clamp(1.5rem, 2.6vw, 2rem);
            font-weight: 800;
            letter-spacing: -0.02em;
        }
        .form-section > p.lead { margin: 0 0 24px; color: var(--ink-soft); }
        label {
            display: block;
            margin-top: 18px;
            font-weight: 700;
            font-size: 0.78rem;
            letter-spacing: 0.06em;
            text-transform: uppercase;
            color: var(--ink-soft);
        }
        label .req { color: #b91c1c; }
        input[type="text"],
        input[type="email"],
        select,
        textarea {
            width: 100%;
            margin-top: 8px;
            padding: 13px 14px;
            border: 2px solid var(--line);
            border-radius: var(--radius-sm);
            font-size: 1rem;
            font-family: inherit;
            background: #fff;
            color: var(--ink);
        }
        input:focus, select:focus, textarea:focus {
            outline: none;
            border-color: var(--yellow);
            box-shadow: 0 0 0 3px rgba(245, 197, 24, 0.25);
        }
        textarea { min-height: 110px; resize: vertical; }
        .row { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }
        @media (max-width: 540px) { .row { grid-template-columns: 1fr; } }
        .checkbox {
            display: flex;
            gap: 12px;
            align-items: flex-start;
            margin-top: 20px;
            font-size: 0.93rem;
            color: var(--ink-soft);
        }
        .checkbox input { width: auto; margin-top: 4px; }
        .checkbox label {
            margin: 0;
            font-weight: 500;
            text-transform: none;
            letter-spacing: 0;
            font-size: 0.93rem;
            color: var(--ink-soft);
        }
        .radio-group { display: flex; gap: 22px; margin-top: 10px; flex-wrap: wrap; }
        .radio-group label {
            margin: 0;
            font-weight: 600;
            font-size: 0.97rem;
            text-transform: none;
            letter-spacing: 0;
            display: inline-flex;
            gap: 8px;
            align-items: center;
            color: var(--ink);
        }
        .radio-group input { width: auto; margin: 0; }
        .form-section button[type="submit"] {
            margin-top: 26px;
            width: 100%;
            padding: 17px;
            border: none;
            border-radius: var(--radius-sm);
            background: var(--yellow);
            color: var(--ink);
            font-size: 1.05rem;
            font-weight: 800;
            cursor: pointer;
            font-family: inherit;
            box-shadow: 0 6px 22px rgba(245, 197, 24, 0.45);
        }
        .form-section button[type="submit"]:hover { background: var(--yellow-hover); }
        .notice {
            padding: 14px 16px;
            border-radius: var(--radius-sm);
            margin-bottom: 16px;
            font-size: 0.95rem;
        }
        .notice.success { background: var(--ok-bg); color: var(--ok-ink); }
        .notice.error { background: var(--err-bg); color: var(--err-ink); }
        .small { font-size: 0.84rem; color: var(--ink-mute); margin-top: 12px; }
        .small a { color: var(--ink-soft); }
        .hp { position: absolute; left: -10000px; top: auto; width: 1px; height: 1px; overflow: hidden; }

        footer.site-footer {
            padding: 44px 0;
            text-align: center;
            font-size: 0.88rem;
            color: var(--ink-mute);
            border-top: 1px solid var(--line);
        }
        footer.site-footer strong { color: var(--ink); }
        footer.site-footer a {
            color: var(--ink-soft);
            text-decoration: none;
        }
        footer.site-footer a:hover { text-decoration: underline; }

        /* Hide top nav text on narrow screens but keep CTA */
        @media (max-width: 720px) {
            .top-nav { display: none; }
            .top-domain { display: none; }
        }
    </style>
    <!-- Cloudflare Web Analytics -->
    <script defer src="https://static.cloudflareinsights.com/beacon.min.js" data-cf-beacon='{"token": "af94f271002d48fba094746dc6b412f6"}'></script>
    <!-- End Cloudflare Web Analytics -->
</head>
<body>

<div class="top">
    <div class="wrap top-inner">
        <a class="logo" href="#">
            <span class="logo-mark" aria-hidden="true">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
                    <rect x="6" y="3" width="12" height="3" rx="1"></rect>
                    <path d="M5 6h14a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1z"></path>
                    <path d="M9 12h6M9 16h4"></path>
                </svg>
            </span>
            <span class="logo-text">
                <strong>Job Site Records</strong>
                <span>Local field notes for contractors</span>
            </span>
        </a>
        <nav class="top-nav" aria-label="Page">
            <a href="guides/">Resources</a>
            <a href="#features">Features</a>
            <a href="#simple">Simple</a>
            <a href="#how">How it works</a>
            <a href="#teams">Teams &amp; Pro</a>
            <a href="#dashboard">Dashboard</a>
            <a href="#privacy">Privacy</a>
            <a href="#faq">FAQ</a>
            <a href="#customers">Feedback</a>
        </nav>
        <div class="top-right">
            <span class="top-domain">jobsiterecords.com</span>
            <a class="btn btn-primary" href="#waitlist">Request early access</a>
        </div>
    </div>
</div>

<header class="hero">
    <div class="wrap hero-grid">
        <div>
            <h1>
                <span class="line">Document the job.</span>
                <span class="line">Share the proof.</span>
            </h1>
            <p class="sub">
                Capture photos, voice notes, and tags as you work. Export a zip with everything in it.
                <strong>It stays on your phone. No account.</strong>
            </p>
            <p class="hero-audience">
                For remodelers, plumbers, electricians, landscapers, painters, and small crews who need job-site proof without paperwork.
            </p>
            <div class="hero-cta">
                <a class="btn btn-primary" href="#waitlist">
                    Request early access
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14M13 6l6 6-6 6"></path></svg>
                </a>
                <a class="btn btn-ghost" href="#how">
                    <span class="play-circle">
                        <svg width="10" height="10" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"></path></svg>
                    </span>
                    See how it works
                </a>
            </div>
            <p class="hero-note">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><path d="m9 12 2 2 4-4"></path></svg>
                100% local. No sign-up. No cloud.
            </p>

            <div id="features" class="features">
                <div class="feature">
                    <span class="feature-ico" aria-hidden="true">
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M3 7h3l2-3h8l2 3h3v12H3z"></path>
                            <circle cx="12" cy="13" r="4"></circle>
                        </svg>
                    </span>
                    <strong>Photos</strong>
                    <span>Take clear, time-stamped photos on site.</span>
                </div>
                <div class="feature">
                    <span class="feature-ico" aria-hidden="true">
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <rect x="9" y="2" width="6" height="12" rx="3"></rect>
                            <path d="M5 11a7 7 0 0 0 14 0"></path>
                            <path d="M12 18v3"></path>
                        </svg>
                    </span>
                    <strong>Voice Notes</strong>
                    <span>Add details hands-free on the go.</span>
                </div>
                <div class="feature">
                    <span class="feature-ico" aria-hidden="true">
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M20 12 12 4H4v8l8 8z"></path>
                            <circle cx="8" cy="8" r="1.5"></circle>
                        </svg>
                    </span>
                    <strong>Tags</strong>
                    <span>Use Before, Issue, After or add your own.</span>
                </div>
                <div class="feature">
                    <span class="feature-ico" aria-hidden="true">
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M4 4h16v4H4z"></path>
                            <path d="M4 8v12h16V8"></path>
                            <path d="M10 12h4l-4 4h4"></path>
                        </svg>
                    </span>
                    <strong>Zip Export</strong>
                    <span>Export all data and media in one zip.</span>
                </div>
            </div>

            <div class="validation-note">
                <strong>Early access opens in waves</strong> so onboarding stays smooth.
                Drop your details below and we'll send you an invitation when your spot is ready.
            </div>
        </div>

        <!-- Phone mock -->
        <div class="phone-wrap" aria-hidden="true">
            <div class="phone">
                <div class="phone-inner">
                    <div class="status-bar">
                        <span>9:41</span>
                        <span class="icons">
                            <svg width="16" height="10" viewBox="0 0 18 10" fill="currentColor"><path d="M1 9h2V6H1zM5 9h2V4H5zM9 9h2V2H9zM13 9h2V0h-2z"/></svg>
                            <svg width="14" height="10" viewBox="0 0 16 10" fill="none" stroke="currentColor" stroke-width="1.4"><path d="M1 4a10 10 0 0 1 14 0M3 6a7 7 0 0 1 10 0M6 8a3 3 0 0 1 4 0"/></svg>
                            <svg width="22" height="10" viewBox="0 0 24 10" fill="currentColor"><rect x="1" y="1" width="20" height="8" rx="2" stroke="currentColor" fill="none" stroke-width="1"/><rect x="3" y="3" width="16" height="4" rx="1"/></svg>
                        </span>
                    </div>
                    <div class="app-header">
                        <svg width="18" height="14" viewBox="0 0 24 18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M2 2h20M2 9h20M2 16h20"/></svg>
                        <div class="app-title">Job Site Records</div>
                        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 0 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.6 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 0 1 0-4h.1a1.7 1.7 0 0 0 1.6-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 0 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 0 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></svg>
                    </div>
                    <div class="segmented">
                        <div class="active">Jobs</div>
                        <div>Timeline</div>
                    </div>

                    <div class="section-label">
                        <strong>My Jobs</strong>
                        <span class="add-pill">+</span>
                    </div>

                    <div class="job-card">
                        <div class="job-thumb"></div>
                        <div class="job-meta">
                            <div class="job-meta-top">
                                <span class="job-name">123 Maple Drive</span>
                                <span class="job-count">18 items ›</span>
                            </div>
                            <div class="job-sub">Kitchen addition</div>
                            <div class="job-date">May 20, 2026</div>
                        </div>
                    </div>
                    <div class="job-card">
                        <div class="job-thumb green"></div>
                        <div class="job-meta">
                            <div class="job-meta-top">
                                <span class="job-name">456 Oak Street</span>
                                <span class="job-count">11 items ›</span>
                            </div>
                            <div class="job-sub">Deck repair</div>
                            <div class="job-date">May 18, 2026</div>
                        </div>
                    </div>
                    <div class="job-card">
                        <div class="job-thumb brown"></div>
                        <div class="job-meta">
                            <div class="job-meta-top">
                                <span class="job-name">789 Pine Road</span>
                                <span class="job-count">22 items ›</span>
                            </div>
                            <div class="job-sub">Bathroom remodel</div>
                            <div class="job-date">May 15, 2026</div>
                        </div>
                    </div>

                    <div class="timeline-head">Recent Timeline</div>
                    <div class="timeline-row">
                        <div class="timeline-meta">
                            <span class="timeline-dot"></span>
                            <span><strong>Today, 9:32 AM</strong> · 123 Maple Drive</span>
                        </div>
                        <div class="tag-strip">
                            <span class="tag before">Before</span>
                            <span class="tag issue">Issue</span>
                            <span class="tag after">After</span>
                        </div>
                        <div class="photo-strip">
                            <div class="photo"></div>
                            <div class="photo b"></div>
                            <div class="photo c"></div>
                        </div>
                        <div class="waveform">
                            <span class="wave-play">
                                <svg width="9" height="9" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
                            </span>
                            <div class="wave-bars">
                                <?php
                                $heights = [6, 14, 10, 18, 8, 20, 12, 16, 6, 14, 10, 4, 12, 18, 14, 8, 16, 10, 14, 20, 12, 8, 18, 10, 14, 6, 12, 16, 8, 14, 10, 18, 6, 12, 16, 10];
                                foreach ($heights as $hgt) {
                                    echo '<span style="height:' . (int)$hgt . 'px"></span>';
                                }
                                ?>
                            </div>
                            <span class="wave-time">0:28</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</header>

<section id="simple">
    <div class="wrap" style="max-width:820px">
        <div class="section-head">
            <span class="eyebrow">Design</span>
            <h2>Simple on purpose.</h2>
            <p class="section-lead">
                We cut the workflow down to what matters on a job site, then we stop. No onboarding wizard, no setup screens before your first photo, and no menus that exist to look impressive in a demo.
            </p>
        </div>
        <ul class="simple-list">
            <li><strong>Open, pick a job, snap.</strong> That is the loop. First useful save happens before you read any documentation.</li>
            <li><strong>One primary action per screen.</strong> The button you need is the big one. Settings stays out of the way until you need it.</li>
            <li><strong>Defaults that work.</strong> Tags, file names, share format, and folder structure are sensible out of the box.</li>
            <li><strong>One hand, with a glove.</strong> Big tap targets, high contrast, no buried popups, no swipe puzzles.</li>
            <li><strong>If it does not help capture, organize, or handoff, it does not ship.</strong> No accounting, no scheduling, no chat. We keep the surface area small on purpose.</li>
        </ul>
    </div>
</section>

<section id="how" class="tint">
    <div class="wrap">
        <div class="section-head">
            <span class="eyebrow">How it works</span>
            <h2>Jobs, capture, export.</h2>
            <p class="section-lead">
                Three tabs: <strong>Jobs</strong>, <strong>Capture</strong>, and <strong>Settings</strong>.
                Everything rolls up under a job in a date-grouped timeline. Fast, glove-friendly,
                and built for how work moves on site.
            </p>
        </div>
        <div class="split">
            <ol class="steps">
                <li>
                    <strong>Create or open a job.</strong>
                    <span>Name, client, address, status, notes. Lightweight fields so the export reads well to outsiders.</span>
                </li>
                <li>
                    <strong>Capture on site.</strong>
                    <span>Photos and voice notes on items, with tags like Before, During, After, Issue, Completed, plus your own trade tags.</span>
                </li>
                <li>
                    <strong>Export what you need.</strong>
                    <span>Select items, generate a zip with an <code>index.html</code> anyone can open, then share through your phone's share sheet.</span>
                </li>
            </ol>
            <div></div>
        </div>
    </div>
</section>

<section id="use-cases">
    <div class="wrap">
        <div class="section-head">
            <span class="eyebrow">What it's for</span>
            <h2>Built for your job site.</h2>
            <p class="section-lead">
                Independent contractors and small crews: remodel, plumbing, electrical, framing, landscaping, painting.
                If you need a clean record for the client, a change order, or Monday morning, this is for you.
            </p>
        </div>
        <div class="grid cols-3">
            <article class="tile">
                <span class="tile-ico" aria-hidden="true">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12h18M3 6h18M3 18h12"/></svg>
                </span>
                <h3>Progress documentation</h3>
                <p>Before, during, and after photos with tags. The homeowner gets a story, not a random camera roll.</p>
            </article>
            <article class="tile">
                <span class="tile-ico" aria-hidden="true">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 9v4M12 17h.01"/><path d="M10.3 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.7 3.86a2 2 0 0 0-3.4 0z"/></svg>
                </span>
                <h3>Issue &amp; defect evidence</h3>
                <p>Water damage, hidden conditions, failed inspections: time-stamped photos and voice notes in one job timeline.</p>
            </article>
            <article class="tile">
                <span class="tile-ico" aria-hidden="true">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6M16 13H8M16 17H8M10 9H8"/></svg>
                </span>
                <h3>Change-order justification</h3>
                <p>Visual plus verbal proof when scope shifts. Less "he said / she said," more "here's what we found Tuesday."</p>
            </article>
            <article class="tile">
                <span class="tile-ico" aria-hidden="true">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg>
                </span>
                <h3>Daily job log</h3>
                <p>A quick chronological trail of what happened on site: trades, weather notes, delays, completions.</p>
            </article>
            <article class="tile">
                <span class="tile-ico" aria-hidden="true">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/></svg>
                </span>
                <h3>Handoff package</h3>
                <p>Pick what matters, export a zip, then share by email, SMS, AirDrop, WhatsApp, or Drive. Your choice.</p>
            </article>
            <article class="tile">
                <span class="tile-ico" aria-hidden="true">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-7 8-13a8 8 0 0 0-16 0c0 6 8 13 8 13z"/><circle cx="12" cy="9" r="2.5"/></svg>
                </span>
                <h3>Glove-friendly on site</h3>
                <p>Built for outdoor use: quick capture loop, big tap targets, high contrast, no buried popups.</p>
            </article>
        </div>
    </div>
</section>

<section id="export" class="tint">
    <div class="wrap">
        <div class="section-head">
            <span class="eyebrow">Export</span>
            <h2>What lands in the zip.</h2>
            <p class="section-lead">
                Every export is plain, portable, and client-readable on any device. Open the summary in a browser.
                No special viewer app.
            </p>
        </div>
        <div class="two-col">
            <div>
                <p style="margin-top:0;color:var(--ink-soft)">
                    The archive opens anywhere. <code>index.html</code> is a static page with no JavaScript and no external assets.
                    Photos, voice notes, and text notes sit in clear folders beside it.
                </p>
                <ul style="color:var(--ink-soft);padding-left:1.2em;margin:0">
                    <li>Photos and voice notes (AAC / m4a) in clear folders</li>
                    <li>Originals kept for export; thumbnails speed up the in-app timeline</li>
                    <li>Share through the same sheet you already use (Mail, Messages, AirDrop, WhatsApp, Files, etc.).</li>
                </ul>
            </div>
            <pre class="export-box" aria-label="Example zip layout">JobSiteRecords_<span class="k">&lt;JobName&gt;</span>_2026-05-14.zip
 ├─ index.html      <span class="k">(opens in any browser)</span>
 ├─ photos/
 │   └─ 2026-05-13_09-15_before_kitchen-demo.jpg
 ├─ voice_notes/
 │   └─ 2026-05-13_10-42_water-damage.m4a
 └─ notes/
     └─ 2026-05-13_10-42.txt</pre>
        </div>
    </div>
</section>

<section id="teams">
    <div class="wrap">
        <div class="section-head">
            <span class="eyebrow">Teams &amp; Pro</span>
            <h2>Optional paid tier: sync, dashboard, and team accounts.</h2>
            <p class="section-lead">
                The mobile app stays <strong>free</strong> for jobs, capture, timeline, and zip export, and that promise is permanent.
                If your crew wants more, you can add a <strong>paid subscription</strong> as an option. It unlocks encrypted cloud sync,
                a <strong>web dashboard</strong> for the office (bigger screen, better for branded PDF reports), and
                <strong>team workspaces</strong> so multiple people share the same jobs, photos, voice notes, and tags under one bill.
                Solo contractors who never want the cloud never pay.
            </p>
            <p class="section-lead" style="margin-top:14px;font-size:0.95rem;color:var(--ink-mute)">
                We keep the scope narrow on purpose: capture, organize per job, and handoff. Not a full PM suite or accounting stack.
            </p>
        </div>
        <div class="two-col">
            <div class="tile">
                <h3 style="margin-top:0;margin-bottom:10px">Free on your phone</h3>
                <p style="margin:0;color:var(--ink-soft)">
                    Full capture workflow, local storage, and zip exports. Works offline. No subscription, no login for that mode,
                    and that path stays free even after the paid tier ships.
                </p>
            </div>
            <div class="tile">
                <h3 style="margin-top:0;margin-bottom:10px">Paid when you opt in</h3>
                <p style="margin:0;color:var(--ink-soft)">
                    Sync across devices, browser-based dashboard, shared access for the team, and Pro outputs like polished PDFs
                    and voice-note transcription. You only pay if you turn this layer on for a workspace.
                </p>
            </div>
        </div>
    </div>
</section>

<section id="dashboard" class="tint">
    <div class="wrap">
        <div class="section-head">
            <span class="eyebrow">Web dashboard</span>
            <h2>The office view of the same jobs.</h2>
            <p class="section-lead">
                When your company turns on the paid workspace, the browser dashboard is where office staff work with the same
                projects the crew captures in the field. You get navigation for jobs, daily logs, photos, documents, reports,
                team settings, and a clear place to build client-ready PDFs without squinting at a phone screen.
            </p>
        </div>
        <div class="dashboard-body">
            <div class="dashboard-copy">
                <p>
                    The <strong>Reports</strong> area is built around branded PDFs: pick a template (for example letterhead),
                    start a <strong>New PDF report</strong>, and track each file from <strong>Generating</strong> to <strong>Ready</strong>.
                    The list ties every report back to a job and address, shows who created it, and when it was generated.
                </p>
                <p>
                    A live <strong>Preview</strong> pane lets you sanity-check layout before you download. That is the kind of
                    work that belongs on a desktop monitor, while the free mobile app stays focused on fast capture on site.
                </p>
                <ul>
                    <li>Shared context for PMs, supers, and admins (same jobs, same timeline items).</li>
                    <li>Filters and pagination when the report list grows.</li>
                    <li>Quick actions such as secure links when you need to send files out of the office.</li>
                </ul>
            </div>
            <figure class="dashboard-figure">
                <img
                    src="assets/dashboard-pdf-reports-light.png"
                    width="1536"
                    height="1024"
                    loading="lazy"
                    decoding="async"
                    alt="Job Site Records web dashboard: sidebar with Dashboard, Jobs, Daily logs, Photos, Documents, Reports, Team, and Settings; Reports view with branded PDF list, template selector, status column, and PDF preview with download.">
                <figcaption class="dashboard-figcaption">
                    Reports workspace: branded PDFs, job-linked rows, status, preview, and download.
                </figcaption>
            </figure>
        </div>
    </div>
</section>

<section id="privacy">
    <div class="wrap">
        <div class="section-head">
            <span class="eyebrow">Privacy</span>
            <h2>Local-first isn't a footnote.</h2>
            <p class="section-lead">
                The workflow is built on one rule: what you collect on the job
                <strong>stays on your phone</strong> until you choose to share it.
            </p>
        </div>
        <div class="tile" style="max-width:820px">
            <ul style="margin:0;padding-left:1.2em;color:var(--ink-soft);line-height:1.7">
                <li>No network calls in the app. Capture, browse, and export all work without a connection.</li>
                <li>No accounts, no passwords, no "sign up to continue."</li>
                <li>No third-party analytics SDKs. We don't send analytics out of the app.</li>
                <li>Privacy policy is bundled inside the app. No remote fetch is required to read it.</li>
                <li>Permissions (camera, microphone, photos, storage on Android) asked just-in-time, with a clear in-app rationale.</li>
                <li>"Clear all data" is a single irreversible action when you want a fresh start.</li>
            </ul>
        </div>
    </div>
</section>

<section id="faq" class="tint">
    <div class="wrap" style="max-width:820px">
        <div class="section-head">
            <span class="eyebrow">FAQ</span>
            <h2>Straight answers.</h2>
        </div>
        <details>
            <summary>Is it really free?</summary>
            <p class="faq-a">Yes. Jobs, capture, timeline, and zip export on your phone stay free. We only charge when a crew chooses the optional paid tier: encrypted cloud sync, the web dashboard, team workspaces under one subscription, and Pro features like branded PDFs and transcription. If you never turn that on, you never pay. We don't sell your data because we don't receive it while you stay local-only.</p>
        </details>
        <details>
            <summary>What is the paid option?</summary>
            <p class="faq-a">It is an add-on for teams that want the same data in the cloud and in a browser. You get sync across phones and tablets, a web dashboard for the office, shared access for staff on one workspace bill, and room for heavier outputs (for example branded PDF reports) that are awkward to build on a small phone screen. The field app itself stays free for local-only use. We keep the scope narrow on purpose: capture, organize per job, and handoff. Not a full PM suite or accounting stack.</p>
        </details>
        <details>
            <summary>Does it work offline?</summary>
            <p class="faq-a">Yes. Fully offline for capture, browse, and export. No login, no network dependency. The crew can work in a basement with no signal and pick right back up.</p>
        </details>
        <details>
            <summary>Do you see my photos or voice notes?</summary>
            <p class="faq-a">No. Everything stays on your device until you share an export through your phone's share sheet.</p>
        </details>
        <details>
            <summary>What format are the exports?</summary>
            <p class="faq-a">Each export is a zip with your photos, voice notes, text notes, and an <code>index.html</code> that opens in any browser. Anyone can open it. No special viewer app.</p>
        </details>
        <details>
            <summary>How do I get started?</summary>
            <p class="faq-a">Request early access below. We're rolling out invitations in waves so onboarding stays smooth. You'll get an email when your spot is ready.</p>
        </details>
        <details>
            <summary>Will it work for my trade?</summary>
            <p class="faq-a">Yes. The workflow is the same no matter the trade. The default tags (Before, During, After, Issue, Completed) work across remodel, plumbing, electrical, framing, painting, landscaping and more. You can add your own.</p>
        </details>
        <details>
            <summary>Who is it for?</summary>
            <p class="faq-a">Independent contractors and small crews who need dated, tagged evidence without paying for heavy enterprise tools.</p>
        </details>
    </div>
</section>

<section id="customers">
    <div class="wrap" style="max-width:820px">
        <div class="section-head">
            <span class="eyebrow">Product feedback</span>
            <h2>We listen, then we ship what matters.</h2>
            <p class="section-lead">
                We talk to contractors and office staff regularly. Tell us what you need on the job or in the office.
                That input feeds what we build next. If a feature would help your team on real work, we are willing to
                work with you on the details so it lands in a way you can use, not as a generic checkbox release.
            </p>
        </div>
    </div>
</section>

<section id="waitlist">
    <div class="wrap" style="max-width:760px">
        <div class="form-section">
            <span class="eyebrow">Early access</span>
            <h2>Request your invitation.</h2>
            <p class="lead">
                Early access is rolling out in waves so onboarding stays smooth. Drop your details below
                and we'll send an invitation when your spot opens. The pain-point field helps us tailor
                onboarding to your trade.
            </p>

            <?php if ($message !== ''): ?>
                <div class="notice success"><?= h($message) ?></div>
            <?php endif; ?>
            <?php if ($error !== ''): ?>
                <div class="notice error"><?= h($error) ?></div>
            <?php endif; ?>

            <form method="post" action="" novalidate>
                <label for="email">Email <span class="req">*</span></label>
                <input type="email" id="email" name="email" required autocomplete="email" value="<?= h($old['email']) ?>">

                <div class="row">
                    <div>
                        <label for="name">Name</label>
                        <input type="text" id="name" name="name" autocomplete="name" value="<?= h($old['name']) ?>">
                    </div>
                    <div>
                        <label for="company">Company</label>
                        <input type="text" id="company" name="company" autocomplete="organization" value="<?= h($old['company']) ?>">
                    </div>
                </div>

                <label for="role">Your role</label>
                <select id="role" name="role">
                    <?php
                    $roles = [
                        '' => 'Select one',
                        'Contractor'      => 'Contractor',
                        'Site manager'    => 'Site manager',
                        'Project manager' => 'Project manager',
                        'Foreman'         => 'Foreman',
                        'Architect'       => 'Architect',
                        'Engineer'        => 'Engineer',
                        'Tradesperson'    => 'Tradesperson (electrician, plumber, etc.)',
                        'Other'           => 'Other',
                    ];
                    foreach ($roles as $value => $labelText) {
                        $sel = $old['role'] === $value ? ' selected' : '';
                        echo '<option value="' . h($value) . '"' . $sel . '>' . h($labelText) . '</option>';
                    }
                    ?>
                </select>

                <label for="pain_point">What's your biggest problem with site documentation today?</label>
                <textarea id="pain_point" name="pain_point" placeholder="e.g. Photos end up in WhatsApp threads and I can't tie them back to a job or a date."><?= h($old['pain_point']) ?></textarea>

                <label style="margin-top:20px">Open to giving us feedback?</label>
                <div class="radio-group">
                    <label>
                        <input type="radio" name="open_to_call" value="yes" <?= $old['open_to_call'] === 'yes' ? 'checked' : '' ?>>
                        Yes
                    </label>
                    <label>
                        <input type="radio" name="open_to_call" value="no" <?= $old['open_to_call'] === 'no' ? 'checked' : '' ?>>
                        No
                    </label>
                </div>

                <div class="hp" aria-hidden="true">
                    <label for="website">Website</label>
                    <input type="text" id="website" name="website" tabindex="-1" autocomplete="off">
                </div>

                <div class="checkbox">
                    <input type="checkbox" id="consent" name="consent" required>
                    <label for="consent">
                        I agree to receive Job Site Records product updates, release notes, and early-access invitations.
                        Unsubscribe any time by replying to an email.
                    </label>
                </div>

                <button type="submit">Request early access</button>
                <p class="small">We won't sell or share your details. You can unsubscribe at any time.</p>
                <p class="small">Questions? <a href="mailto:contact@jobsiterecords.com">contact@jobsiterecords.com</a></p>
            </form>
        </div>
    </div>
</section>

<footer class="site-footer">
    <div class="wrap">
        <strong>Job Site Records</strong> · jobsiterecords.com<br>
        <a href="mailto:contact@jobsiterecords.com">contact@jobsiterecords.com</a><br>
        Local-first field notes for contractors. Made for the field.
    </div>
</footer>

</body>
</html>
