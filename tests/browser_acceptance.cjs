// Synthetic end-to-end checks against an already running app. No account login.
// node tests/browser_acceptance.cjs URL OUTPUT_DIR [BROWSER_EXECUTABLE]
const { chromium } = require(process.env.PUI_PLAYWRIGHT_MODULE || 'playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
(async () => {
  const url = process.argv[2] || 'http://127.0.0.1:3876';
  const dir = path.resolve(process.argv[3] || 'artifacts/browser');
  fs.mkdirSync(dir, { recursive: true });
  const browser = await chromium.launch({headless:true, ...(process.argv[4] ? {executablePath:process.argv[4]} : {})});
  console.log('Browser:', browser.version());
  const context = await browser.newContext({viewport:{width:1440,height:1000},acceptDownloads:true});
  const page = await context.newPage();
  const errors = [];
  page.setDefaultTimeout(15000);
  page.on('pageerror', e => errors.push(e.message));
  const waitText = (id, text) => page.waitForFunction(({id,text}) => document.querySelector(id)?.textContent.includes(text), {id,text});
  const checkReferences = async heading => {
    await waitText('#questionnaire_references_heading',heading);
    const citations = page.locator('#questionnaire_source p[lang="en"]');
    assert.equal(await citations.count(),2);
    assert.ok(await citations.first().isVisible() && await citations.last().isVisible());
    assert.match(await citations.first().innerText(),/^Hou, Y\. \(2013\)\..*China Statistics Press\.$/s);
    assert.match(await citations.last().innerText(),/Cyberpsychology, Behavior, and Social Networking, 23\(5\), 312–328\./);
    assert.deepEqual(await citations.locator('em').allTextContents(),[
      'Zhonghua yixue tongji baike quanshu: Jiankang celiang fence',
      'Cyberpsychology, Behavior, and Social Networking','23'
    ]);
    assert.ok(await citations.first().evaluate(p => parseFloat(getComputedStyle(p).textIndent) === -48));
    assert.ok(await citations.last().locator('a[href="https://doi.org/10.1089/cyber.2019.0468"]').isVisible());
  };
  const selectize = async (id, value) => {
    await page.locator(`#${id}-selectized`).click();
    await page.locator(`.selectize-dropdown:visible [data-value="${value}"]`).click();
  };
  const download = async (id, name) => {
    await page.waitForFunction(id => {
      const button = document.querySelector(id);
      return button?.getAttribute('href') && !button.classList.contains('disabled');
    },id);
    const [result] = await Promise.all([
      page.waitForEvent('download',{timeout:45000}),
      page.locator(id).click()
    ]);
    assert.equal(await result.failure(), null);
    await result.saveAs(path.join(dir,name));
  };
  try {
    await page.goto(url);
    await page.locator('#disclaimer_continue').waitFor();
    await page.locator('#disclaimer_continue').click();
    await page.locator('.shiny-notification').waitFor();
    assert.equal(await page.locator('#individual_age').count(), 0);
    console.log('Unchecked consent blocks use: PASS');
    await page.locator('#disclaimer_ack').check();
    await page.locator('#disclaimer_continue').click();
    const graph = page.locator('#trajectory_plot');
    const panel = graph.locator('rect.nsewdrag');
    const hover = '#trajectory_plot .hoverlayer .hovertext';
    await panel.waitFor();
    await page.screenshot({path:path.join(dir,'trajectory.png'),fullPage:true});
    const rect = await panel.boundingBox();
    const move = (x, y) => page.mouse.move(rect.x + rect.width*x, rect.y + rect.height*y, {steps:5});
    const drag = async (x0, y0, x1, y1) => {
      await move(x0,y0);
      await page.mouse.down();
      await move(x1,y1);
      await page.mouse.up();
    };
    const ranges = () => graph.evaluate(g => [g._fullLayout.xaxis.range.slice(),g._fullLayout.yaxis.range.slice()]);
    const span = range => range[1] - range[0];
    const initial = await ranges();
    await move(0.54,0.47);
    await waitText(hover,'P75');
    const hoverText = await page.locator(hover).textContent();
    assert.match(hoverText,/男性.*\d+\.\d{2} 岁/);
    for (const label of ['P25','P50','P75']) assert.match(hoverText,new RegExp(label+'\\s*\\d+\\.\\d{2}'));
    await graph.screenshot({path:path.join(dir,'trajectory-hover.png')});
    await drag(0.24,0.22,0.70,0.78);
    await page.waitForFunction(() => {
      const r = document.querySelector('#trajectory_plot')._fullLayout.xaxis.range;
      return r[1] - r[0] < 8;
    });
    const zoomed = await ranges();
    assert.ok(span(zoomed[0]) < span(initial[0]) && span(zoomed[1]) < span(initial[1]));
    await move(0.52,0.5);
    await page.mouse.wheel(0,-180);
    await page.waitForFunction(oldSpan => {
      const r = document.querySelector('#trajectory_plot')._fullLayout.xaxis.range;
      return r[1] - r[0] < oldSpan - 0.01;
    },span(zoomed[0]));
    const wheeled = await ranges();
    await graph.locator('.modebar-btn[data-val="pan"]').click();
    await drag(0.46,0.48,0.61,0.60);
    const panned = await ranges();
    assert.ok(Math.abs(panned[0][0] - wheeled[0][0]) > 0.05);
    assert.ok(Math.abs(span(panned[0]) - span(wheeled[0])) < 1e-6);
    const ageLine = page.locator('.shiny-input-container:has(#trajectory_age) .irs-line');
    const rail = await ageLine.boundingBox();
    await page.mouse.click(rail.x + 12,rail.y + rail.height/2);
    await page.waitForFunction(() => document.querySelector('#trajectory_plot').layout.shapes[0].x0 < 12);
    assert.deepEqual(await ranges(),panned);
    await panel.dblclick({position:{x:rect.width*0.5,y:rect.height*0.5}});
    await page.waitForFunction(() => {
      const r = document.querySelector('#trajectory_plot')._fullLayout.xaxis.range;
      return r[0] === 9 && r[1] === 18;
    });
    assert.deepEqual(await ranges(),initial);
    for (const [kind,unit] of [['sd','标准差'],['growth','增长率'],['p50','P50']]) {
      await page.locator(`input[name="trajectory_kind"][value="${kind}"]`).check();
      await page.waitForFunction(unit => {
        const line = document.querySelector('#trajectory_plot').data.at(-1);
        return line.name.includes(unit);
      },unit);
      await move(0.55,0.45);
      await waitText(hover,unit);
    }
    await page.locator('input[name="trajectory_sex"][value="Female"]').check();
    await selectize('app_language','en');
    await page.waitForFunction(() => document.querySelector('#trajectory_plot')._fullLayout.xaxis.title.text === 'Age (years)');
    await move(0.55,0.45);
    await waitText(hover,'Female');
    await waitText(hover,'years');
    await page.setViewportSize({width:390,height:844});
    await page.waitForFunction(() => {
      const g = document.querySelector('#trajectory_plot');
      return g._fullLayout.width <= window.innerWidth && g._fullLayout.width > 150;
    });
    assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth <= window.innerWidth + 2));
    await page.setViewportSize({width:1440,height:1000});
    await selectize('app_language','zh');
    console.log('Plotly hover, box/wheel zoom, pan, age marker, double-click reset and bilingual views: PASS');
    await page.locator('a[data-value="individual"]').click();
    await page.locator('#individual_age').fill('14.5');
    await selectize('individual_sex','Female');
    await page.locator('#individual_score').fill('36');
    await page.locator('#individual_score').press('Tab');
    await waitText('#individual_summary','50.75');
    await download('#individual_pdf','individual-zh.pdf');
    await page.screenshot({path:path.join(dir,'individual-zh.png'),fullPage:true});
    console.log('Chinese individual result and PDF download: PASS');
    await selectize('app_language','en');
    await waitText('#individual_summary','Percentile 50.75');
    assert.equal(await page.locator('#individual_age').inputValue(),'14.5');
    await download('#individual_pdf','individual-en.pdf');
    console.log('English switch retains inputs and PDF download: PASS');
    await page.locator('input[name="individual_mode"][value="items"]').check();
    await waitText('#questionnaire_progress','0 / 17');
    await waitText('#questionnaire_version_note','differs from the Chinese Y-IAT');
    assert.ok(await page.locator('#questionnaire_version_note').isVisible());
    await checkReferences('References');
    await waitText('#questionnaire_source','copyrighted by their respective authors');
    assert.equal(await page.locator('#individual_pdf').count(),0);
    for (const number of [1,2,3,5,6,8,10,11,12,13,14,15,16,17,18,19,20]) {
      await page.locator(`input[name="yiat_item_${number}"][value="1"]`).check();
    }
    await waitText('#questionnaire_progress','Total score: 17');
    await download('#individual_pdf','questionnaire-en.pdf');
    await selectize('app_language','zh');
    await waitText('#questionnaire_progress','总分为 17');
    await checkReferences('参考文献');
    await waitText('#questionnaire_source','版权归各自作者所有');
    assert.equal(await page.locator('input[name^="yiat_item_"]:checked').count(),17);
    console.log('17-item completion, PDF and bilingual answer retention: PASS');
    await page.locator('a[data-value="about"]').click();
    await waitText('#about_content','建模原理');
    assert.equal(await page.locator('#about_content ol > li').count(),4);
    await selectize('app_language','en');
    await waitText('#about_content','Score your own sample in R');
    assert.equal(await page.locator('#about_content pre code').count(),5);
    assert.ok(await page.locator('#about_content').getByText('How the PUI norms work').isVisible());
    await page.setViewportSize({width:390,height:844});
    assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth <= window.innerWidth + 2));
    await page.setViewportSize({width:1440,height:1000});
    await selectize('app_language','zh');
    console.log('Bilingual modelling explanation and local R tutorial: PASS');
    await page.locator('a[data-value="batch"]').click();
    await download('#batch_template','template.xlsx');
    await page.locator('#batch_file').setInputFiles(path.join(dir,'template.xlsx'));
    await waitText('#batch_status','已检查并计算 2 行');
    await download('#batch_download','batch-zh.xlsx');
    await selectize('app_language','en');
    await waitText('#batch_status','Checked and scored 2 row(s).');
    await download('#batch_download','batch-en.xlsx');
    await download('#batch_download','batch-en-repeat.xlsx');
    console.log('Template / HTTP upload / bilingual repeated Excel download: PASS');
    fs.writeFileSync(path.join(dir,'invalid.xlsx'), 'not an Excel archive');
    await page.locator('#batch_file').setInputFiles(path.join(dir,'invalid.xlsx'));
    await page.waitForFunction(()=>!document.querySelector('#batch_download'));
    assert.ok(!(await page.locator('#batch_status').innerText()).includes('Checked and scored'));
    console.log('Invalid replacement clears downloadable old result: PASS');
    await page.setViewportSize({width:390,height:844});
    await page.screenshot({path:path.join(dir,'mobile-batch.png'),fullPage:true});
    const overflow = await page.evaluate(()=>document.documentElement.scrollWidth > window.innerWidth + 2);
    assert.equal(overflow,false);
    console.log('Mobile width has no horizontal overflow: PASS');
    const second = await context.newPage();
    await second.goto(url);
    await second.locator('#disclaimer_decline').click();
    await second.waitForFunction(()=>document.body.textContent.includes('You have exited'));
    assert.equal(await second.locator('#individual_age').count(),0);
    await second.close();
    assert.deepEqual(errors,[]);
    console.log('Fresh session consent/decline isolation and no JS errors: PASS');
    console.log('All browser checks passed.');
  } catch(error) {
    await page.screenshot({path:path.join(dir,'failure.png'),fullPage:true}).catch(()=>{});
    fs.writeFileSync(path.join(dir,'failure.txt'), await page.locator('body').innerText().catch(()=>''));
    throw error;
  } finally { await browser.close(); }
})().catch(error=>{console.error(error);process.exitCode=1;});
