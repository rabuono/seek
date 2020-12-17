console.log('markdown_io_spec');
describe('Markdown', function () {
  beforeEach(function() {
    console.log('before-start');
    this.timeout(10000);
    MagicLamp.load("project/markdown");
    console.log('before-end');
  });
  
  it('html rendered', function(done) {
    console.log('1')
    expectedOut= `<h1>header</h1>\n\n<p>Some text</p>\n\n<h2>second header</h2>\n\n<p><em>italic <strong>bold</strong> text</em></p>\n\n<p>&gt; Another paragraph</p>`
    expect(jQuery('#description').html().trim()===expectedOut).to.equal(true)

    unexpectedOut= `# header\nSome text\n\n## second header\n\n_italic **bold** text_\n\n> Another paragraph'`
    expect(jQuery('#description').html().trim()===unexpectedOut).to.equal(false)
    
    done();
  });
});
