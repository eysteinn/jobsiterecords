<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Comparison</span>
    <h1>Rugged cameras still slap. Phones still win Tuesday.</h1>
    <p class="lead">A dedicated site camera with optical zoom and a wrist strap is beautiful on a bridge deck at dusk. It is also another charger, another SD card, another “who took the camera home?” fight. Phones are mediocre cameras that are always in the wrong pocket—which means they actually get used.</p>

    <h2>Break out the real camera when</h2>
    <p>You need reach, low light without noise soup, or a client marketing shoot billed separately. Documenting a mud ring height is not that.</p>

    <h2>Stay on the phone when</h2>
    <p>You need captions, tags, voice, and export in one loop. Convenience beats sensor size for 80% of field evidence.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Phone-first workflow—import from real cameras later if you must, but we optimize for the thing in your pocket.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related">
        <h2>Related</h2>
        <ul>
            <li><a href="/answers/">All answers</a></li>
            <li><a href="/answers/caption-and-tags-vs-exif-only-evidence.php">Captions vs EXIF</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Phone photos vs dedicated site camera',
    'description' => 'When rugged cameras beat phones for construction photos—and when phone capture plus captions wins on consistency.',
    'canonical_path' => '/answers/phone-photos-vs-dedicated-site-camera.php',
    'body' => $body,
]);
