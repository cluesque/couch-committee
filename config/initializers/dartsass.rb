# Bootstrap 5.3's SCSS still relies on @import and deprecated Sass functions.
Rails.application.config.dartsass.build_options << " --quiet-deps --silence-deprecation=import"
