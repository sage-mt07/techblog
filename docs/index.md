---
layout: custom_default
title: ホーム
home: true
---
# Techblog

以下のページをご覧ください：

{% assign dev_pages = site.pages | where_exp: "page", "page.url contains '/dev/' and page.title" %}
{% assign grouped = dev_pages | group_by: "category" %}

{% for group in grouped %}
  <h2>{{ group.name }}</h2>
  <ul>
    {% for page in group.items %}
      <li><a href="{{ page.url | relative_url }}">{{ page.title }}</a></li>
    {% endfor %}
  </ul>
{% endfor %}
