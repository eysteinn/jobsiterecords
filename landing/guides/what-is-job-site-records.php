<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$canonicalPath = '/guides/what-is-job-site-records.php';

$faqLd = json_encode([
    '@context' => 'https://schema.org',
    '@type' => 'FAQPage',
    'mainEntity' => [
        [
            '@type' => 'Question',
            'name' => 'What is Job Site Records?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Job Site Records is a contractor-focused mobile app for capturing job-site evidence: photos, voice notes, short captions, tags, and text notes organized per job on a timeline. The Phase 1 product is free, works fully offline, does not require an account, keeps content on the device, and can export selected items as a zip archive through the phone share sheet.',
            ],
        ],
        [
            '@type' => 'Question',
            'name' => 'Does Job Site Records upload my photos to the cloud?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'In Phase 1, no. Capture and browsing happen locally; sharing only occurs when you explicitly export and use the OS share sheet. A later optional paid tier may add encrypted team sync and a web dashboard for organizations that opt in.',
            ],
        ],
        [
            '@type' => 'Question',
            'name' => 'Who is Job Site Records for?',
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text' => 'Independent contractors and small crews in trades like remodel, plumbing, electrical, framing, painting, and landscaping who need fast, glove-friendly documentation for clients, change orders, and internal records.',
            ],
        ],
    ],
], JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Guides</span>
    <h1>What is Job Site Records?</h1>
    <p class="lead"><strong>Job Site Records</strong> is a mobile app for contractors that captures <strong>photos, voice notes, captions, tags, and text notes</strong> per job on a simple timeline. Phase 1 is <strong>free, offline-first, and account-less</strong>: data stays on the phone until you export a zip and share it yourself.</p>

    <h2>One-sentence definition</h2>
    <p>Local-first field notes for job-site evidence and handoff. Narrow scope, few taps, built for poor signal and rushed crews.</p>

    <h2>What it is not</h2>
    <p>It is not a full construction project management suite, accounting system, scheduling board, or "everything app." The focus stays on capture, then organize per job, then export.</p>

    <section aria-labelledby="faq-quick">
        <h2 id="faq-quick">Quick answers</h2>
        <h3>What is Job Site Records?</h3>
        <p>Job Site Records is a contractor-focused mobile app for capturing job-site evidence: photos, voice notes, short captions, tags, and text notes organized per job on a timeline. The Phase 1 product is free, works fully offline, does not require an account, keeps content on the device, and can export selected items as a zip archive through the phone share sheet.</p>
        <h3>Does Job Site Records upload my photos to the cloud?</h3>
        <p>In Phase 1, no. Capture and browsing happen locally; sharing only occurs when you explicitly export and use the OS share sheet. A later optional paid tier may add encrypted team sync and a web dashboard for organizations that opt in.</p>
        <h3>Who is Job Site Records for?</h3>
        <p>Independent contractors and small crews in trades like remodel, plumbing, electrical, framing, painting, and landscaping who need fast, glove-friendly documentation for clients, change orders, and internal records.</p>
    </section>

    <div class="guide-cta">
        <strong>Get early access</strong>
        <p>Request early access and we will invite you in waves as builds stabilize.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related guides">
        <h2>Related</h2>
        <ul>
            <li><a href="local-private-job-site-data.php">Local, private job site data</a></li>
            <li><a href="job-site-records-free-vs-pro-teams.php">Free app vs Pro teams (roadmap)</a></li>
            <li><a href="offline-job-site-documentation.php">Offline job site documentation</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'What is Job Site Records?',
    'description' => 'Definition: Job Site Records is a free, offline-first contractor app for photos, voice, tags, and zip export. Local on device in Phase 1.',
    'canonical_path' => $canonicalPath,
    'body' => $body,
    'json_ld' => $faqLd,
]);
