<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Guides</span>
    <h1>Voice notes for contractors</h1>
    <p class="lead">Typing in dust and gloves is slow. Speaking a ten-second note next to the photo you just took preserves <strong>tone, jargon, and measurements</strong> without fighting the keyboard. Job Site Records treats voice as a first-class capture. Not an afterthought.</p>

    <h2>How voice fits the timeline</h2>
    <p>You can attach a voice note to a photo or save voice as its own timeline item. Playback uses a simple waveform UI so you can scrub what you said without exporting first. Everything stays on device in Phase 1 until you choose to share an export.</p>

    <h2>Transcription is not part of Phase 1</h2>
    <p>Automatic speech-to-text is <strong>not</strong> in the first shipping app: no AI, no server-side processing while you stay local-only. A future optional team subscription may add transcription so spoken notes become editable text for search and reports. Until then, voice remains audio you (and your client) can play back from the zip export.</p>

    <h2>Export includes audio</h2>
    <p>Zip exports place voice files under a clear folder with the other media, and the bundled <code>index.html</code> references them with standard audio elements so anyone with the zip can listen in a browser.</p>

    <div class="guide-cta">
        <strong>Capture voice on site</strong>
        <p>Request early access to Job Site Records and we will invite you when your spot opens.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related guides">
        <h2>Related</h2>
        <ul>
            <li><a href="offline-job-site-documentation.php">Offline job site documentation</a></li>
            <li><a href="export-job-site-zip-html-csv.php">Export a job as zip (HTML + CSV)</a></li>
            <li><a href="job-site-records-free-vs-pro-teams.php">Free app vs Pro teams (roadmap)</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Voice notes for contractors',
    'description' => 'Why voice notes matter on job sites, how they sit in the timeline, and what ships in Phase 1 vs future transcription. Job Site Records.',
    'canonical_path' => '/guides/voice-notes-for-contractors.php',
    'body' => $body,
]);
