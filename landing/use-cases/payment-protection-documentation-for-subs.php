<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Use case</span>
    <h1>Subs: shorter arguments, same money</h1>
    <p class="lead">Nobody likes liens. What subs actually dislike is spending Friday re-explaining Tuesday. A dated photo trail is not a lawyer—it is a mute button for half the “that was not in scope” loop.</p>

    <h2>What to capture without being weird about it</h2>
    <p>Conditions before you start your slice. Anything the GC walked past. Significant extras you were told to “just handle.” Photos of completed work before the next trade buries it. You are not building a court case on site; you are saving your PM from inventing memory.</p>

    <h2>Send packages, not drip torture</h2>
    <p>One zip per event beats seventeen texts with two photos each. Humans pay faster when the file makes them look organized too.</p>

    <p class="muted">Not legal advice.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Local capture, zip export—your evidence stays yours until you send it.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related">
        <h2>Related</h2>
        <ul>
            <li><a href="/use-cases/">All use cases</a></li>
            <li><a href="/answers/zip-export-vs-cloud-only-daily-logs.php">Zip vs cloud-only</a></li>
            <li><a href="/guides/subcontractor-to-gc-documentation-handoff.php">GC handoff guide</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Payment protection documentation for subs',
    'description' => 'Field documentation habits for subcontractors: scope photos, extras, clean exports—shorter arguments, not legal advice.',
    'canonical_path' => '/use-cases/payment-protection-documentation-for-subs.php',
    'body' => $body,
]);
