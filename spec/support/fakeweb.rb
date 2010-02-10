
FakeWeb.allow_net_connect = false

FakeWeb.register_uri(:any, 'https://s3.amazonaws.com:443', :body => '')
