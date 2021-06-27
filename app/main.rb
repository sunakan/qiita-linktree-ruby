# coding: utf-8
require 'net/http'
require 'json'
require 'yaml'
require 'oga'

class NotHttpUrlError < StandardError
  def initialize(url:)
    super(url)
  end
end
class NotQiitaHostError < StandardError
  def initialize(host:)
    super(host)
  end
end
class NotQiitaItemPathError < StandardError
  def initialize(path:)
    super(path)
  end
end

def qiita?(host_name:)
  if host_name == 'qiita.com'
    true
  elsif host_name.end_with?('.qiita.com')
    true
  else
    false
  end
end

def qiita_item_path?(url_path:)
  # /{USER_NAME}/items/:item_id
  splited = url_path.split('/')
  splited.size==4 && splited[2]=='items'
end

def extract_qiita_item_id(url:)
  if !qiita?(host_name: url.host)
    raise NotQiitaHostError.new(host: url.host)
  end
  if !qiita_item_path?(url_path: url.path)
    raise NotQiitaItemPathError.new(path: url.path)
  end
  url.path.split('/').last
end

def get_html(endpoint:)
  url  = URI.parse(endpoint)
  req  = Net::HTTP::Get.new(url.request_uri)
  if ENV['QIITA_ACCESS_TOKEN']
    req['Authorization'] = "Bearer #{ENV['QIITA_ACCESS_TOKEN']}"
  end
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  response     = http.request(req)
  if response.is_a?(Net::HTTPOK)
    JSON.parse(response.body)['rendered_body']
  else
    STDERR.puts "--デバッグ用"
    STDERR.puts "残り：#{response['rate-remaining']}/#{response['rate-limit']} 回"
    STDERR.puts "リセット：#{Time.at(response['rate-reset'].to_i)}"
  end
  #File.read('./sample.html')
end

def extract_links(html:)
  parsed     = Oga.parse_html(html)
  a_elements = parsed.xpath('//a')
  a_elements.map { |node|
    {
      text: node.text().strip,
      url: node.get('href'),
      weblinks: []
    }
  }
end

def filter_correct_url(links:)
  links.map { |link_node|
    begin
      url = remove_query_and_anchor(url: link_node[:url])
      link_node.merge({url: url})
    rescue NotHttpUrlError => e
      # STDERR.puts e
      nil
    rescue URI::InvalidURIError => e
      # STDERR.puts e
      nil
    end
  }.compact
end

def exclude_qiita_user_content_url(links:)
  links.filter { |link_node|
    ! link_node[:url].start_with?('https://camo.qiitausercontent.com')
  }
end

def exclude_qiita_files_url(links:)
  links.filter { |link_node|
    ! link_node[:url].include?('qiita.com/files/')
  }
end

# @params [String] url
# @return [Array] Webリンク
def scraping_weblinks(url:)
  url = begin
    URI.parse(url)
  rescue => e
    return []
  end
  if qiita?(host_name: url.host)
    item_id = begin
      extract_qiita_item_id(url: url)
    rescue => e
      return []
    end
    endpoint       = "https://qiita.com/api/v2/items/#{item_id}"
    html           = get_html(endpoint: endpoint)
    links          = extract_links(html: html)
    filtered_links = filter_correct_url(links: links)
    filtered_links = exclude_qiita_user_content_url(links: filtered_links)
    filtered_links = exclude_qiita_files_url(links: filtered_links)
    filtered_links
  else
    []
  end
end

def remove_query_and_anchor(url:)
  url = URI.parse(url)
  if ! url.kind_of?(URI::HTTP)
    raise NotHttpUrlError.new(url: url)
  end
  "#{url.scheme}://#{url.host}#{url.path}"
end

url = ARGV[0] || 'https://qiita.com/sunakan/items/02198c4d46d416fc93a6'
url = remove_query_and_anchor(url: url)

weblink_set = Set[]
weblinktree_root_node = {
  text: url,
  url: url,
  weblinks: nil,
}
queue = [weblinktree_root_node]

while queue.size > 0 do
  node = queue.shift # dequeue
  url  = node[:url]
  if weblink_set.include?(url)
    next
  end
  sleep 0.2
  weblink_set.add(url)
  weblinks        = scraping_weblinks(url: url)
  node[:weblinks] = weblinks
  queue.concat(weblinks) # 一括enqueue
end

puts YAML.dump(JSON.parse(weblinktree_root_node.to_json()))
