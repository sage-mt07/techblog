---
layout: custom_default
title: ホーム
home: true
---
# Techblog v

以下のページをご覧ください：

<details>
  <summary>ページ一覧を表示／非表示</summary>
  
  {% assign dev_pages = site.pages | where_exp: 'page', 'page.url contains "/dev/" ' %}
  {% assign grouped = dev_pages | group_by: 'category' %}
  
  {% for group in grouped %}
    <h3>{{ group.name }}</h3>
    <ul>
      {% for page in group.items %}
        <li><a href="{{ page.url | relative_url }}">{{ page.title }}</a></li>
      {% endfor %}
    </ul>
  {% endfor %}
</details>
