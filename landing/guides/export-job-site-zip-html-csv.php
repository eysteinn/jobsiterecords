<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Guides</span>
    <h1>Export a job as zip (HTML + media)</h1>
    <p class="lead">Clients and PMs do not want another login. They want a <strong>folder they can open</strong>. Job Site Records builds a zip archive you send through your phone's share sheet. Email, AirDrop, WhatsApp, Drive, whatever you already use.</p>

    <h2>What is inside the archive</h2>
    <p>Exports are designed to be useful even outside the app. A typical bundle includes:</p>
    <ul>
        <li><code>index.html</code>   a static page with the job header, items grouped by date, captions, tags, and embedded audio players for voice notes. No JavaScript, no CDN assets.</li>
        <li>Folders for <strong>photos</strong>, <strong>voice_notes</strong>, and <strong>text notes</strong> with readable filenames.</li>
    </ul>

    <h2>What is not in Phase 1</h2>
    <p>The mobile MVP does <strong>not</strong> generate PDFs. Heavy, branded reporting belongs on larger screens; a future optional team subscription is planned to add a web dashboard and PDF templates. Phase 1 still hands off professional evidence via zip and HTML.</p>

    <h2>You control selection</h2>
    <p>Exports are built from items you select. By default you can take everything or trim to a date range. Captions, tags, timestamps, and notes are included with toggles so you can match what the receiver needs.</p>

    <div class="guide-cta">
        <strong>See it in the app</strong>
        <p>Request early access to Job Site Records on the homepage.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related guides">
        <h2>Related</h2>
        <ul>
            <li><a href="before-during-after-construction-photos.php">Before, during, and after construction photos</a></li>
            <li><a href="voice-notes-for-contractors.php">Voice notes for contractors</a></li>
            <li><a href="job-site-records-free-vs-pro-teams.php">Free app vs Pro teams (roadmap)</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Export a job as zip (HTML + media)',
    'description' => 'What is inside Job Site Records zip exports: index.html, photos, voice notes, and text notes. No PDF in Phase 1.',
    'canonical_path' => '/guides/export-job-site-zip-html-csv.php',
    'body' => $body,
]);
