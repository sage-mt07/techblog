---
layout: custom_default
title: ホーム
home: true
---
# Techblog v

以下のページをご覧ください：

{% for page in site.pages %}
  {% if page.title and page.url != '/' and page.url != '/URL-PATH' %}
    {% unless page.url contains 'assets'  %}
      <li><a href="{{ page.url | relative_url }}">{{ page.title }}</a></li>
    {% endunless %}
  {% endif %}
{% endfor %}
</ul>
