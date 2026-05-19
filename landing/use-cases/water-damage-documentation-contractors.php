<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Use case</span>
    <h1>Water damage jobs without turning your phone into a courtroom</h1>
    <p class="lead">You are not a claims adjuster. You are someone who tears out wet stuff and puts buildings back together. Still, the photos you take on day one often decide whether a carrier argues about what was “pre-existing.” So shoot like someone who will forget the smell by Thursday.</p>

    <h2>Practical sequence</h2>
    <p>Establish the room. Show the source if it is visible (supply line, failed pan, ice dam stain pattern). Capture materials affected—subfloor, base trim, cabinetry—toes of cabinets love to hide swelling. Meter readings in frame if you carry one. After tear-out, shoot framing and cavity air before it goes closed again.</p>

    <h2>Keep claims language out of your mouth in captions</h2>
    <p>Describe what you see (“staining 18” up drywall at north wall”) not legal conclusions. Let adjusters do their job; your job is a clear visual chain.</p>

    <p class="muted">Not insurance or legal advice—just field habits.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Offline capture, per-job timeline, zip export for carriers or owners.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related">
        <h2>Related</h2>
        <ul>
            <li><a href="/use-cases/">All use cases</a></li>
            <li><a href="/trades/plumbing-job-site-photo-documentation.php">Plumbing documentation</a></li>
            <li><a href="/guides/document-issues-and-change-orders.php">Issues &amp; change orders</a></li>
        </ul>
    </nav>
</article>
HTML;

render_seo_page([
    'title' => 'Water damage documentation for contractors',
    'description' => 'Field photo habits for water mitigation and rebuild work: room context, materials, readings, captions that stay factual.',
    'canonical_path' => '/use-cases/water-damage-documentation-contractors.php',
    'body' => $body,
]);
