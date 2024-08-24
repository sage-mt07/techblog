---
title: Welcome to My Tech Blog
layout: default
---

# Welcome to My Site

This is a sample site using the Midnight theme.
<ul>
  {% for post in site.posts %}
    <li>
      <a href="{{ post.url }}">{{ post.title }}</a>
      {{ post.excerpt }}
    </li>
  {% endfor %}
</ul>