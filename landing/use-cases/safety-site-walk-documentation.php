<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Use case</span>
    <h1>Safety walks nobody posts on Instagram</h1>
    <p class="lead">This is not OSHA compliance theatre. It is the Tuesday photo of the trench nobody backfilled yet, the extension cord running through a puddle because humans are humans, the dumpster blocking the hydrant view. You are building a diary so when someone asks “was it like that on Wednesday?” you have a date on the image.</p>

    <h2>Keep it boring</h2>
    <p>Wide shot of the hazard, medium shot of context, caption with trade + “needs X.” No speeches. If it is fixed an hour later, grab an “after” so the story has a closed loop.</p>

    <h2>Not legal advice</h2>
    <p>Your safety program is yours. Photos are just receipts for your own crew culture—and sometimes for GCs who like paper trails.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Quick capture, tags like <code>Issue</code>, export when asked.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related">
        <h2>Related</h2>
        <ul>
            <li><a href="/use-cases/">All use cases</a></li>
            <li><a href="/examples/example-three-day-job-log-entries.php">Sample job log entries</a></li>
            <li><a href="/guides/daily-construction-job-log.php">Daily job log guide</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Safety site walk documentation',
    'description' => 'Practical photo habits for informal safety walks: hazards, context, dated captions—not a substitute for formal compliance programs.',
    'canonical_path' => '/use-cases/safety-site-walk-documentation.php',
    'body' => $body,
]);
