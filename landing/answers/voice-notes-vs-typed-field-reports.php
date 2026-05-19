<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Comparison</span>
    <h1>Voice vs typing on a lift</h1>
    <p class="lead">Typing with thumbs in full sun is a skill. So is narrating while holding a flashlight in your teeth. Pick the medium that matches the gloves—not the one your high school English teacher prefers.</p>

    <h2>Voice wins when</h2>
    <p>You are moving, explaining sequence, or quoting what the GC said while walking. It is also faster for “same as yesterday but swap left/right” nonsense that takes forever to type.</p>

    <h2>Text wins when</h2>
    <p>Model numbers, breaker labels, serial stickers—stuff you will copy into a CO later. A photo of the sticker plus a typed line beats mis-hearing “B as in Bob” on a windy roof.</p>

    <h2>Hybrid is not cheating</h2>
    <p>Photo + short caption + 20-second voice is the adult version of “I will remember this.” You will not.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Voice sits next to photos on the same timeline.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related">
        <h2>Related</h2>
        <ul>
            <li><a href="/answers/">All answers</a></li>
            <li><a href="/examples/example-short-field-voice-note-script.php">Sample voice script</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Voice notes vs typed field reports',
    'description' => 'When contractors should use voice vs typed field notes: gloves, model numbers, sequence, and hybrid capture.',
    'canonical_path' => '/answers/voice-notes-vs-typed-field-reports.php',
    'body' => $body,
]);
