# encoding: utf-8
# frozen_string_literal: true

require 'spec_helper'

describe JsRegex::Converter::SetConverter do
  it 'preserves hex escape members' do
    given_the_ruby_regexp(/[\x41]/)
    expect_js_regex_to_be(/[\x41]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'ABC', with_results: %w[A])
  end

  it 'preserves hex escape ranges' do
    given_the_ruby_regexp(/[\x41-\x43]+/)
    expect_js_regex_to_be(/[\x41-\x43]+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'ABC', with_results: %w[ABC])
  end

  context 'when sets are nested' do
    it 'flattens simple nested sets' do
      given_the_ruby_regexp(/[a-z[0-9]]+/)
      expect_js_regex_to_be(/[a-z0-9]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'ab_12', with_results: %w[ab 12])
    end

    it 'flattens nested sets in negative sets' do
      given_the_ruby_regexp(/[^a-c[0-9]]+/)
      expect_js_regex_to_be(/[^a-c0-9]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'abc123xyz', with_results: %w[xyz])
    end

    it 'isnt distracted by escaped brackets' do
      given_the_ruby_regexp(/[a-z\][0-9\[]ä-ü]+/)
      expect_js_regex_to_be(/[a-z\]0-9\[ä-ü]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: ']a_1[', with_results: %w(]a 1[))
    end

    it 'drops negative nested sets from negative sets' do
      given_the_ruby_regexp(/[^a[^b]]+/) # matches any non-a that is b, i.e. b
      expect_js_regex_to_be(/[^a]+/)
      expect_warning
    end

    it 'can flatten multiple nested sets' do
      given_the_ruby_regexp(/[[a-c][x-z][0-2]]+/)
      expect_js_regex_to_be(/[a-cx-z0-2]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'bmx_123', with_results: %w[b x 12])
    end

    it 'can flatten multiple sets nested in negative sets' do
      given_the_ruby_regexp(/[^a-c[x-z][0-2]]+/)
      expect_js_regex_to_be(/[^a-cx-z0-2]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'bmx_123', with_results: %w[m _ 3])
    end

    it 'can flatten deeply nested sets' do
      given_the_ruby_regexp(/[a-c[x-z[0-2]]]+/)
      expect_js_regex_to_be(/[a-cx-z0-2]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'bmx_123', with_results: %w[b x 12])
    end

    it 'can flatten deeply nested sets in negative sets' do
      given_the_ruby_regexp(/[^a-c[x-z[0-2]]]+/)
      expect_js_regex_to_be(/[^a-cx-z0-2]+/)
      expect_no_warnings
      expect_ruby_and_js_to_match(string: 'bmx_123', with_results: %w[m _ 3])
    end

    it 'drops deeply nested negative sets with warning' do
      given_the_ruby_regexp(/[a-c[x-z[^0-2]]]+/)
      expect_js_regex_to_be(/[a-cx-z]+/)
      expect_warning('nested negative set')
    end

    it 'drops deeply nested negative sets from negated sets with warning' do
      given_the_ruby_regexp(/[^a-c[x-z[^0-2]]]+/)
      expect_js_regex_to_be(/[^a-cx-z]+/)
      expect_warning('nested negative set')
    end

    it 'drops deeply nested negative sets with properties with warning' do
      given_the_ruby_regexp(/[^a-c[x-z[^\p{ascii}]]]+/)
      expect_js_regex_to_be(/[^a-cx-z]+/)
      expect_warning('nested negative set')
    end
  end

  it 'expands the hex type in positive sets' do
    given_the_ruby_regexp(/[x-y\h]+/)
    expect_js_regex_to_be(/[x-yA-Fa-f0-9]+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'zxa3n', with_results: %w[xa3])
  end

  it 'extracts the non-hex type from positive sets' do
    given_the_ruby_regexp(/[a-c\H]+/)
    expect_js_regex_to_be(/(?:[a-c]|[^A-Fa-f0-9])+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'zxa3n', with_results: %w[zxa n])
  end

  it 'expands the hex type in negative sets' do
    given_the_ruby_regexp(/[^x-y\h]+/)
    expect_js_regex_to_be(/[^x-yA-Fa-f0-9]+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'zxa3n', with_results: %w[z n])
  end

  it 'drops the non-hex type from negative sets with warning' do
    given_the_ruby_regexp(/[^a-c\H]+/)
    expect_js_regex_to_be(/[^a-c]+/)
    expect_warning('unsupported nonhex type in negative set')
  end

  it 'does not create empty sets when extracting types' do
    given_the_ruby_regexp(/[\H]+/)
    expect_js_regex_to_be(/[^A-Fa-f0-9]+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'zxa3n', with_results: %w[zx n])
  end

  it 'does not create empty sets when dropping all contents' do
    given_the_ruby_regexp(/[\p{Deseret}]/)
    expect_js_regex_to_be(//)
    expect_warning("unsupported property '[\\p{Deseret}]'")
  end

  it 'does not extracts other types from sets' do
    given_the_ruby_regexp(/[x-y\s\S\d\D\w\W]+/)
    expect_js_regex_to_be(/[x-y\s\S\d\D\w\W]+/)
    expect_no_warnings
  end

  it 'extracts posix classes from sets' do
    given_the_ruby_regexp(/[äöüß[:ascii:]]+/)
    expect_js_regex_to_be(/(?:[äöüß]|[\x00-\x7F])+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'ñbäõ_ß', with_results: %w[bä _ß])
  end

  it 'extracts negative posix classes from sets' do
    given_the_ruby_regexp(/[x-z[:^ascii:]]+/)
    expect_js_regex_to_be(/(?:[x-z]|[^\x00-\x7F])+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'xañbäõ_ß', with_results: %w[x ñ äõ ß])
  end

  it 'extracts \p-style properties from sets' do
    given_the_ruby_regexp(/[äöüß\p{ascii}]+/)
    expect_js_regex_to_be(/(?:[äöüß]|[\x00-\x7F])+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'ñbäõ_ß', with_results: %w[bä _ß])
  end

  it 'extracts abbreviated \p-style properties from sets' do
    given_the_ruby_regexp(/[ä\p{ahex}]+/)
    expect_js_regex_to_be(/(?:[ä]|[\u0030-\u0039\u0041-\u0046\u0061-\u0066])+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'ñbäõ_ß', with_results: %w[bä])
  end

  it 'extracts negative \p{^-style properties from sets' do
    given_the_ruby_regexp(/[x-z\p{^ascii}]+/)
    expect_js_regex_to_be(/(?:[x-z]|[^\x00-\x7F])+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'xañbäõ_ß', with_results: %w[x ñ äõ ß])
  end

  it 'extracts negative \P-style properties from sets' do
    given_the_ruby_regexp(/[x-z\P{ascii}]+/)
    expect_js_regex_to_be(/(?:[x-z]|[^\x00-\x7F])+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'xañbäõ_ß', with_results: %w[x ñ äõ ß])
  end

  it 'extracts double-negated \P{^-style properties from sets' do
    given_the_ruby_regexp(/[äöüß\P{^ascii}]+/)
    expect_js_regex_to_be(/(?:[äöüß]|[\x00-\x7F])+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'ñbäõ_ß', with_results: %w[bä _ß])
  end

  it 'wraps set extractions in a passive alternation group with the set' do
    given_the_ruby_regexp(/[a-f\p{ascii}]+/)
    expect_js_regex_to_be(/(?:[a-f]|[\x00-\x7F])+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'efghß', with_results: %w[efgh])
  end

  it 'wraps multiple set extractions in a passive alternation group' do
    given_the_ruby_regexp(/[a-f\p{ascii}\p{ascii}]+/)
    expect_js_regex_to_be(/(?:[a-f]|[\x00-\x7F]|[\x00-\x7F])+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'efghß', with_results: %w[efgh])
  end

  it 'retains other set contents if there are multiple set extractions' do
    given_the_ruby_regexp(/[ä-ö\h\p{ascii}]+/)
    expect_js_regex_to_be(/(?:[ä-öA-Fa-f0-9]|[\x00-\x7F])+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'efghß', with_results: %w[efgh])
  end

  it 'removes the parent set if it is depleted after extractions are done' do
    given_the_ruby_regexp(/[[a-z]]+/)
    expect_js_regex_to_be(/[a-z]+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'abc', with_results: %w[abc])
  end

  it 'creates an alternation when extracting all set contents' do
    given_the_ruby_regexp(/[\H[:ascii:]]+/)
    expect_js_regex_to_be(/(?:[^A-Fa-f0-9]|[\x00-\x7F])+/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'zxa3n', with_results: %w[zxa3n])
  end

  it 'drops properties in negative sets with warning' do
    given_the_ruby_regexp(/[^a\p{ascii}]+/)
    expect_js_regex_to_be(/[^a]+/)
    expect_warning('property in negative set')
  end

  it 'drops set intersections with warning' do
    given_the_ruby_regexp(/[a-c&&x-z]/)
    expect_js_regex_to_be(/[a-cx-z]/)
    expect_warning('set intersection')
  end

  it 'drops astral plane set members with warning' do
    given_the_ruby_regexp(/[a-z😁0-9]/)
    expect_js_regex_to_be(/[a-z0-9]/)
    expect_warning('astral plane')
  end

  it 'drops astral plane ranges with warning' do
    given_the_ruby_regexp(/[😁-😲]/)
    # FIXME: Regexp::Scanner will not detect ranges made of astral plane chars,
    # instead seeing 3 separate members. The member '-' will survive processing,
    # causing the set to match '-'. This should be fixed in Regexp::Scanner.
    # expect_js_regex_to_be(//)
  end

  it 'preserves bmp unicode ranges' do
    # current javascript versions support these
    given_the_ruby_regexp(/[字-汉]/)
    expect_js_regex_to_be(/[字-汉]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: '孙孜', with_results: %w[孙 孜])
  end

  it 'preserves the backspace pseudo set' do
    given_the_ruby_regexp(/[x\b]/)
    expect_js_regex_to_be(/[x\b]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: "a\bz", with_results: %W[\b])
  end

  it 'preserves the backspace pseudo set in negated sets' do
    given_the_ruby_regexp(/[^x\b]/)
    expect_js_regex_to_be(/[^x\b]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: "a\bz", with_results: %w[a z])
  end

  it 'converts literal newline members into newline escapes' do
    given_the_ruby_regexp(/[a
b]/)
    expect_js_regex_to_be(/[a\nb]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: "x\ny", with_results: %W[\n])
  end

  it 'preserves newline escape members' do
    given_the_ruby_regexp(/[a\nb]/)
    expect_js_regex_to_be(/[a\nb]/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: "x\ny", with_results: %W[\n])
  end

  it 'adds case-swapped literal member dupes if subject to a local i-option' do
    given_the_ruby_regexp(/[a](?i)[a](?-i:[a](?i:[^a-fG-Y]))/)
    expect_js_regex_to_be(/[a][aA]([a]([^a-fA-FG-Yg-y]))/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: 'aAaZ', with_results: %w[aAaZ])
    expect_ruby_and_js_not_to_match(string: 'AAaZ')
  end

  it 'does not add duplicates for literal members that cant be swapped' do
    given_the_ruby_regexp(/(?i:[A 1234567890_B])/)
    expect_js_regex_to_be(/([Aa 1234567890_Bb])/)
    expect_no_warnings
    expect_ruby_and_js_to_match(string: '1', with_results: %w[1])
  end

  it 'does not add case-swapped ranges that would be illegal' do
    given_the_ruby_regexp(/(?i:[A-z])/)
    expect_js_regex_to_be(/([A-z])/)
    expect_warning('nested case-insensitive range')
  end

  it 'warns for case-sensitive members in case-insensitive regexes' do
    given_the_ruby_regexp(/[a](?-i)[b]/i)
    expect_warning("nested case-sensitive set member '[b]'")
    expect_js_regex_to_be(/[a][b]/i)
  end

  context 'with add_g_flag false' do
    it 'sets no g flag' do
      given_the_ruby_regexp(/pattern/, add_g_flag: false)
      expect_js_regex_options_to_be('')
    end
  end
  context 'with add_g_flag true' do
    it 'sets g flag' do
      given_the_ruby_regexp(/pattern/, add_g_flag: true)
      expect_js_regex_options_to_be('g')
    end
  end

  context 'without add_g_falg' do
    it 'adds g flag by default' do
      given_the_ruby_regexp(/pattern/)
      expect_js_regex_options_to_be('g')
    end
  end
end
