class Netgear < Oxidized::Model
  using Refinements

  comment '!'
  prompt /^(\([\w\s\-.]+\)\s[#>])$/

  # using a multiline RE here allows removing the paging prompt entirely.
  expect /\n--More-- or \(q\)uit$/m do |data, re|
    send ' '
    data.sub re, ''
  end

  cmd :secret do |cfg|
    cfg.gsub!(/password (\S+)/, 'password <hidden>')
    cfg.gsub!(/encrypted (\S+)/, 'encrypted <hidden>')
    cfg.gsub!(/snmp community (\S+) (.*)$/, 'snmp community <hidden> \\2')
    cfg.gsub!(/snmp-server community (\S+)$/, 'snmp-server community <hidden>')
    cfg.gsub!(/snmp-server community (\S+) (\S+) (\S+)/, 'snmp-server community \\1 \\2 <hidden>')
    cfg
  end

  cfg :telnet do
    username /^(User:|Applying Interface configuration, please wait ...)/
    password /^Password:/i
  end

  cfg :telnet, :ssh do
    post_login do
      if vars(:enable) == true
        cmd "enable"
      elsif vars(:enable)
        cmd "enable", /[pP]assword:\s?$/
        cmd vars(:enable)
      end
      cmd "terminal length 0" if !vars(:smartpro) || vars(:smartpro) == false
    end
    # quit / logout will sometimes prompt the user:
    #
    #     The system has unsaved changes.
    #     Would you like to save them now? (y/n)
    #
    # As no changes will be made over this simple SSH session, we can safely choose "n" here.
    if vars(:smartpro) == true
      pre_logout 'exit'
      pre_logout 'exit'
    else
      pre_logout 'quit'
      pre_logout 'n'
    end
  end

  cmd :all do |cfg, cmdstring|
    new_cfg = comment "COMMAND: #{cmdstring}\n"
    new_cfg << cfg.each_line.to_a[1..-2].join
    # remove triple-line-breaks from paging but NOT in the config blocks (exit preceeded)
    new_cfg.gsub! /(?<!exit\n)^$\n\n\n/m, ''
    new_cfg
  end

  cmd 'show version' do |cfg|
    cfg.gsub! /(Current Time\.+ ).*/, '\\1 <removed>'
    # the below line likes to include...gibberish on gs108t
    cfg.gsub! /(FASTPATH IPv6 Management).*/m, "\\1\n"
    comment cfg
  end

  cmd 'show bootvar' do |cfg|
    # more gs108t-series oddities, in the image selection output
    cfg.gsub!(/ \x80.*/n, '')
    comment cfg
  end
  cmd 'show running-config' do |cfg|
    cfg.gsub! /(System Up Time).*/, '\\1 <removed>'
    cfg.gsub! /\e\[.\e\[.K/, ''
    cfg.gsub! /\cH/, ''
    cfg.gsub! /(Current SNTP Synchronized Time:).*/, '\\1 <removed>'
    cfg
  end
end
