FROM ruby:3.2-alpine
COPY server.rb /server.rb
HEALTHCHECK --interval=1s CMD pgrep ruby
CMD ["ruby", "/server.rb"]
