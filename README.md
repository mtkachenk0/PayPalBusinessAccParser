```sh
sudo apt-get install ruby
sudo gem install $(grep -vE "^\s*#" gem-requirements.txt  | tr "\n" " ")
----
install chromedriver...
create symlink to /usr/local/bin/chromedriver
```