<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Use case</span>
    <h1>Rough-in photos you will not curse six months later</h1>
    <p class="lead">Drywall turns archaeology into guesswork. The fix is not “more photos,” it is the same boring shots every house: panel schedule legible, nail plates where you swore you put them, bath fan ducts that actually exit, hose bibs labeled, low-voltage smurf before insulation.</p>

    <h2>Pick a route and walk it</h2>
    <p>Clockwise from garage panel works. Or follow the plumbing tree. What fails is random hopping—you always miss the one bay the drywall crew covers first.</p>

    <h2>Voice if your hands are full of Romex</h2>
    <p>Ten seconds: “Master bath north wall—two CAT6 + coax, height 48, stud left of mirror centerline.” Future you will nod instead of squinting.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Timeline + tags + voice, offline on site.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related">
        <h2>Related</h2>
        <ul>
            <li><a href="/use-cases/">All use cases</a></li>
            <li><a href="/trades/framing-rough-carpentry-documentation.php">Framing photos</a></li>
            <li><a href="/guides/before-during-after-construction-photos.php">Before / during / after</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'New construction rough-in photo record',
    'description' => 'Rough-in photo habits for new builds: repeatable walk routes, panel labels, nail plates, voice for stud locations.',
    'canonical_path' => '/use-cases/new-construction-rough-in-photo-record.php',
    'body' => $body,
]);
