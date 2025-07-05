require 'nokogiri'

class SeaLink < Oxidized::Model
  # this is a serial port server, not a switch per se.
  # Tested on a SeaLevel SeaLink 4161 FW 3.3.0
  # this is a collection of selector crimes
  cmd '/index.htm' do |cfg|
    data = {}
    page = Nokogiri::HTML(cfg)
    # we pull the system _type_ and hostname out of the header. there's only one h2.
    banner = page.css('h2').map(&:text)[0]
    matches = banner.match(/^(?<model>[A-z0-9]+)\((?<hostname>[A-z0-9]+)\)/)
    # this munge...assumes a *lot* about this output. it's the only td block at 79%...
    # ...and we *know* all the values
    soup = page.css("td[width='79%%']").css('p').map(&:text)
    data["system"] = {
      'hostname' => matches[:hostname],
      'model'    => matches[:model],
      'ether'    => soup[0].gsub('-', ':'),
      # soup[1] is uptime
      'firmware' => soup[2],
      'dhcp'     => soup[3],
      'ip'       => soup[4],
      'gateway'  => soup[5],
      'netmask'  => soup[6]
    }
    # the *only* unnumbered list on the page is protocols. so we can grab the items in it.
    data["protocols"] = page.css('li').map(&:text).map { |s| s.strip }.delete_if { |s| s !~ /\w/ }
    "## Summary:\n#{JSON.pretty_generate(data)}\n"
  end

  cmd '/administration.htm' do |cfg|
    data = {}
    page = Nokogiri::HTML(cfg)
    soup = page.css('form').css('table')
    data["general"] = {
      'advertise' => soup.css('input[value="AdvertiseOn"]').to_s.match(/checked/) ? true : false,
      'nagle'     => soup.css('input[value="EnableNagle"]').to_s.match(/checked/) ? true : false
    }
    data["timeouts"] = {
      'idle'  => soup.css('input[name="IdleTimeout"]')[0]['value'],
      'retry' => soup.css('input[name="ActiveRetry"]')[0]['value'],
      'drop'  => soup.css('input[name="ActiveTimeout"]')[0]['value']
    }
    data["security"] = {
      'use_password' => soup.css('input[value="RequirePasswordNo"]').to_s.match(/checked/) ? false : true
    }
    "## Administration:\n#{JSON.pretty_generate(data)}\n"
  end

  cmd '/portsettings.htm' do |cfg|
    data = {}
    portlist = []
    page = Nokogiri::HTML(cfg)
    soup = page.css('form')
    # this is probably the most unwise yet, but! all the port headers are wrapped in <b>.
    # so if we know how many ports there are, we know the indexing to ask for inputs directly.
    portcount = soup.css('b').length
    data["defaults"] = portlist
    while portlist.length < portcount
      portsel = portlist.length ? portlist.length.to_s : "0"
      portlist.push({
                      'port'     => portlist.length + 1,
                      'speed'    => soup.css("input[name=\"P#{portsel}_BaudRate\"]")[0]['value'].to_i,
                      'databits' => soup.css("select[name=\"P#{portsel}_DataBits\"]").css('option[selected]').map(&:text)[0].to_i,
                      'stopbits' => soup.css("select[name=\"P#{portsel}_StopBits\"]").css('option[selected]').map(&:text)[0].to_i,
                      'parity'   => soup.css("select[name=\"P#{portsel}_Parity\"]").css('option[selected]').map(&:text)[0],
                      'flowctrl' => soup.css("select[name=\"P#{portsel}_FlowControl\"]").css('option[selected]').map(&:text)[0],
                      'mode'     => soup.css("select[name=\"P#{portsel}_RsMode\"]").css('option[selected]').map(&:text)[0],
                      'proto'    => soup.css("select[name=\"P#{portsel}_Protocol\"]").css('option[selected]').map(&:text)[0],
                      'forcedef' => soup.css("input[name=\"P#{portsel}_SuppressChanges\"]").to_s.match(/checked/) ? true : false,
                      'remote'   => {
                        'enabled'     => soup.css("input[name=\"P#{portsel}_ActiveConnect\"]").to_s.match(/checked/) ? true : false,
                        'destination' => "#{soup.css("input[name=\"P#{portsel}_IpAddressA\"]")[0]['value']}.#{soup.css("input[name=\"P#{portsel}_IpAddressB\"]")[0]['value']}.#{soup.css("input[name=\"P#{portsel}_IpAddressC\"]")[0]['value']}.#{soup.css("input[name=\"P#{portsel}_IpAddressD\"]")[0]['value']}:#{soup.css("input[name=\"P#{portsel}_Port\"]")[0]['value']}"
                      }
                    })
    end
    "## Portsettings:\n#{JSON.pretty_generate(data)}\n"
  end

  cfg :http do
    @secure = false
  end
end
