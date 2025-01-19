---
layout: custom_default
title: ホーム
---

# Techblog

以下のページをご覧ください：

<ul>
{% for page in site.pages %}
  {% if page.title and page.url != '/' and page.url != '/URL-PATH' %}
    {% unless page.url contains 'assets'  %}
      <li><a href="{{ page.url }}">{{ page.title }}</a></li>
    {% endunless %}
  {% endif %}
{% endfor %}
</ul>
