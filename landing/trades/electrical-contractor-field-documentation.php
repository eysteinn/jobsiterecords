<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/lib/seo-layout.php';

$body = <<<'HTML'
<article class="guide">
    <span class="eyebrow">Trade</span>
    <h1>Electrical proof that is not just “it lit up”</h1>
    <p class="lead">Inspectors have pet peeves. Owners have Google. You have a phone that can immortalize a torque spec sticker before drywall commits crimes. Shoot the boring stuff: nail plates, recessed IC ratings, derate labels, neutral bars if policy allows photos inside live panels—only when safe and de-energized per your rules.</p>

    <h2>Mud rings and box fill arguments</h2>
    <p>Before device install, capture depth, ring stack, cable count entering the box. Drywallers have a gift for making that evidence disappear.</p>

    <h2>Temp power tells stories</h2>
    <p>GFCI labels, cord routing, panel knockouts—if it looks sketchy in a photo, fix it before someone else takes the picture.</p>

    <div class="guide-cta">
        <strong>Job Site Records</strong>
        <p>Tag <code>Rough-in</code> vs <code>Trim</code> so exports match how inspectors walk.</p>
        <a class="btn btn-primary" href="/#waitlist">Request early access</a>
    </div>

    <nav class="related" aria-label="Related"><h2>Related</h2><ul>
        <li><a href="/trades/">All trades</a></li>
        <li><a href="/examples/sample-rough-in-email-to-gc.php">Sample rough-in email</a></li>
    </ul></nav>
</article>
HTML;

render_seo_page([
    'title' => 'Electrical contractor field documentation',
    'description' => 'Photo habits for electricians: panels, nail plates, mud rings, temp power, rough vs trim tags.',
    'canonical_path' => '/trades/electrical-contractor-field-documentation.php',
    'body' => $body,
]);
