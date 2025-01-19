---
layout: custom_default
title: ホーム
---

# Techblog１２３

以下のページをご覧ください：

<ul>
{% for page in site.pages %} 
  {% if  page.url != '/' and page.url != '/techblog/URL-PATH' and page.url != '/techblog/' %}
    {% unless page.url contains 'assets' or page.url contains 'dev' %}
      <li><a href="{{ page.url }}">{{ page.title }}</a></li>
    {% endunless %}
  {% endif %}
{% endfor %}
</ul>
