import dropbox

access_token = "..."

client = dropbox.client.DropboxClient(access_token)
quota = client.account_info()[u'quota_info']
perc = (100 * (quota[u'normal'] + quota[u'shared'])) / quota[u'quota']
print perc
