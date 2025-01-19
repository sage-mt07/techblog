---
layout: custom_default
title: ホーム
home: true
---
# Techblog v

以下のページをご覧ください：
<div class="accordion">

  
  {% assign dev_pages = site.pages | where_exp: 'page', 'page.url contains "/dev/" and page.title' %}
  {% assign grouped = dev_pages | group_by: 'category' %}
  
  {% for group in grouped %}
  <details>
  <summary>{{ group.name }} <span class="count">({{ group.items | size }})</span></summary>

    <ul>
      {% for page in group.items %}
        <li><a href="{{ page.url | relative_url }}">{{ page.title }}</a></li>
      {% endfor %}
    </ul>
    </details>
  {% endfor %}
   <!-- About ページの手動追加 -->
  <details>
    <summary>About</summary>
    <ul>
      <li><a href="{{ site.baseurl }}/about">自己紹介ページ</a></li>
    </ul>
  </details>
</div>
