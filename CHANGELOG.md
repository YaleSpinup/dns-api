# DNSApi Changelog

# 0.1.0
* implement read actions

# 0.2.0
* Implement record creation actions
* Cleanup schema validation logic

# 0.3.0
* Implement record deletion

# 0.4.0
* Implement IP assignment/deletion
* Add get/delete elements by [proteus] :id

# 0.4.1
* Dockerfile updates

# 0.4.2
* Move import config script to $APPDIR

# 0.4.3
* limit canary ip testing to 10 tries (so we don't hammer proteus)

# 0.4.4
* Add support for user-defined properties when assigning an IP

# 0.5.0
* Changed to Puma

# 0.5.1
* Return JSON object representation of the Proteus ApiEntity instead of strings
