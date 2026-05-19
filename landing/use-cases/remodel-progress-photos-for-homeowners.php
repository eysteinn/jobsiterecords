<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Use case</span>
    <h1>Remodel progress photos homeowners actually read</h1>
    <p class="lead">Most owners do not want a portal login. They want proof you showed up, that the messy middle is normal, and that the expensive parts are installed correctly before they disappear behind drywall. If your update takes more than two minutes to skim, it will get forwarded to someone who will misread it.</p>

    <h2>What works on Friday at 6pm</h2>
    <p>Four to seven photos max. One voice note if something needs tone (“we found rot at the sill—options are A or B”). Captions that sound like you texted a friend who owns a house, not like marketing copy. If you always shoot the same corners—kitchen sink wall, fridge niche, panel—people learn the rhythm and panic less.</p>

    <h2>What quietly fails</h2>
    <p>Dumping fifty unlabeled shots from the camera roll. Mixing kids’ soccer with their backsplash. Sending “update” with no date in the subject line so Gmail turns it into archaeology. A per-job timeline fixes most of that without turning you into a documentarian.</p>

    <h2>Handoff without drama</h2>
    <p>When you export, curate. Owners remember the last thing they saw. Make that last thing accurate: paint touchups, caulk, hardware straight, breaker labels if you touched the panel.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Per-job timeline, offline capture, zip when you are ready. Request early access on the homepage.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related">
        <h2>Related</h2>
        <ul>
            <li><a href="/use-cases/">All use cases</a></li>
            <li><a href="/examples/sample-weekly-homeowner-update-email.php">Sample weekly update email</a></li>
            <li><a href="/guides/before-during-after-construction-photos.php">Before / during / after photos</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Remodel progress photos for homeowners',
    'description' => 'How remodel crews can send homeowner updates people actually read: fewer photos, consistent angles, dated exports.',
    'canonical_path' => '/use-cases/remodel-progress-photos-for-homeowners.php',
    'body' => $body,
]);
