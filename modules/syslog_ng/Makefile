PLATFORMS=docker/ubuntu-12.04/ruby-1.8.7 \
		 docker/ubuntu-14.04/ruby-1.9.3 \
		 docker/centos-6/ruby-1.8.7 \
		 docker/centos-7/ruby-2.0.0

all: build check

build: .gemfile fig.yml
	git archive -o module.tar.gz HEAD
	for dir in $(PLATFORMS); do \
		cp -u .gemfile $$dir/Gemfile; \
		cp -u module.tar.gz $$dir/module.tar.gz; \
	done
	fig build

check:
	fig up -d
	fig ps

ps:
	fig ps

logs:
	fig logs

clean: 
	fig rm --force
	for dir in $(PLATFORMS); do \
		rm -f $$dir/Gemfile; \
		rm -f $$dir/module.tar.gz; \
	done

.PHONY: all check ps clean logs
