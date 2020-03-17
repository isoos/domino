import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

class ParsedSource {
  final List<Element> templates;
  final String path;

  ParsedSource(this.templates, [this.path]);
}

ParsedSource parseToCanonical(String html, {String defaultNamespace = 'd'}) {
  final templates = <Element>[];

  final root = html_parser.parseFragment(html);

  for(final element in root.children) {
    final localName = element.localName;
    if(element.localName.endsWith('.')) {
      final parts = localName.split('.');
      final methodName = parts[parts.length-2];
      String namespace = parts.sublist(0, parts.length-2).join('.');
      if(namespace == '') {
        namespace = defaultNamespace;
      }
      final template = Element.tag('d-template');
      template.attributes.addAll(element.attributes);
      template.nodes.addAll(element.nodes);
      template.attributes['*'] = methodName;
      template.attributes['d-namespace'] = namespace;
      templates.add(template);
    }
  }

  templates.addAll(root.children.where((e)=>e.localName == 'd-template'));

  if (templates.isEmpty) {
    templates.add(Element.tag('d-template')..nodes.addAll(root.nodes));
  }

  for (final templateElem in templates) {
    final varSlot = Element.tag('d-template-var')
        ..attributes['name'] = '\$dSlots'
        // TODO: _i0 import alias is hardcoded
        ..attributes['type'] = 'Map<String, void Function(_i0.DomContext)>'
        //..attributes['library'] = 'package:domino/src/experimental/idom.dart'
        ..attributes['default'] = '{}';
    templateElem.append(varSlot);

    for (final key in templateElem.attributes.keys.toList()) {
      final attr = key.toString();
      if (!attr.contains('-') && !attr.contains('*')) {
        final value = templateElem.attributes.remove(key);
        final parts = value.split('#').map((s) => s.trim()).toList();
        var library = 'dart:core';
        if (parts.length > 1 &&
            (parts[0].contains(':') || parts[0].endsWith('.dart'))) {
          library = parts.removeAt(0);
        }
        final type = parts.removeAt(0);
        bool required = false;
        if (parts.contains('required')) {
          parts.remove('required');
          required = true;
        }
        String defaultValue;
        final defaultAttr = parts.firstWhere((p) => p.startsWith('default:'),
            orElse: () => null);
        if (defaultAttr != null) {
          parts.remove(defaultAttr);
          defaultValue = defaultAttr.substring(8).trim();
        }
        String documentation;
        if (parts.isNotEmpty) {
          documentation = parts.removeAt(0);
        }
        final varElem = Element.tag('d-template-var')
          ..attributes['name'] = attr
          ..attributes['library'] = library
          ..attributes['type'] = type;
        if (required) {
          varElem.attributes['required'] = 'true';
        }
        if (defaultValue != null) {
          varElem.attributes['default'] = defaultValue;
        }
        if (documentation != null) {
          varElem.attributes['doc'] = documentation;
        }
        templateElem.nodes.insert(0, varElem);
      }
    }

    _rewriteAll(templateElem.nodes);
  }

  return ParsedSource(templates);
}

void _pullAttr(Element node, String tag, {Iterable<String> alternatives}) {
  final attrs = [tag, if (alternatives != null) ...alternatives]
      .where((s) => s != null)
      .toList();
  final first = attrs.firstWhere((a) => node.attributes.containsKey(a),
      orElse: () => null);
  if (first != null) {
    final v = node.attributes.remove(first);
    final elem = Element.tag(tag);
    if (v.isNotEmpty) {
      elem.attributes['*'] = v;
    }
    node.replaceWith(elem);
    elem.append(node);
  }
}

void _rewriteAll(NodeList list) {
  for (int i = 0; i < list.length; i++) {
    Node old;
    while (old != list[i]) {
      old = list[i];
      _rewrite(old);
    }
  }
}

void _rewrite(Node node) {
  if (node is Element) {
    _pullAttr(node, 'd-for', alternatives: ['*for']);
    _pullAttr(node, 'd-if', alternatives: ['*if']);
    _pullAttr(node, 'd-else-if', alternatives: ['*else-if', '*elseif']);
    _pullAttr(node, 'd-else', alternatives: ['*else']);

    for (final key in node.attributes.keys.toList()) {
      if (key is String && key.startsWith('#')) {
        node.attributes.remove(key);
        node.attributes['d-key'] = '\'${key.substring(1)}\'';
      }
    }

    if (node.localName == 'd-call') {
      final expr = node.attributes.remove('*');
      if (expr != null) {
        final parts = expr.split('#').map((p) => p.trim()).toList();

        if (parts.first.endsWith('.dart') || parts.first.endsWith('.html')) {
          node.attributes['d-library'] ??= parts.removeAt(0);
        }
        if (parts.isNotEmpty) {
          final method = parts.removeAt(0);
          final fullMethod = method.replaceAll('-', '_');
          node.attributes['d-method'] ??= fullMethod;
        }
      }
      final libValue = node.attributes['d-library'];
      if (libValue != null && libValue.endsWith('.html')) {
        node.attributes['d-library'] = libValue.replaceAll('.html', '.g.dart');
      }

      if(!node.children.any((c) => c.localName == 'd-slot')) {
        // add default node if it does not have any
        final dslot = Element.tag('d-slot')
          ..attributes['d-method'] = ''
          ..nodes.addAll(node.nodes);
        node.nodes.clear();
        node.append(dslot);
      } else {
        // remove every non-slot node
        for(final cnode in node.nodes) {
          if(cnode is Element && cnode.localName == 'd-slot') {
            continue;
          } else {
            cnode.remove();
          }
        }
      }
    }

    if(node.localName == 'd-call-slot') {
      node.attributes['d-method'] ??= '';
    }
    if(node.localName == 'd-slot') {
      node.attributes['d-method'] ??= '';
    }

    _rewriteAll(node.nodes);
  }
}
