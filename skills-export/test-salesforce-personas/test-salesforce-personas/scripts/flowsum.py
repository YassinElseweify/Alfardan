"""Compact, readable summary of a Flow metadata XML file.
Usage: python flowsum.py <file.flow-meta.xml> [...]"""
import sys
import xml.etree.ElementTree as ET

NS = '{http://soap.sforce.com/2006/04/metadata}'


def t(el, path):
    x = el.find(NS + path.replace('/', '/' + NS))
    return x.text if x is not None else None


def val(el):
    if el is None:
        return None
    for c in el:
        return f"{c.tag.replace(NS, '')}={c.text}"
    return None


def conds(el):
    out = []
    for c in el.findall(NS + 'conditions'):
        out.append(f"{t(c, 'leftValueReference')} {t(c, 'operator')} {val(c.find(NS + 'rightValue'))}")
    logic = t(el, 'conditionLogic') or t(el, 'filterLogic')
    return (f"[{logic}] " if logic else '') + ' ; '.join(out)


def filters(el):
    out = []
    for c in el.findall(NS + 'filters'):
        out.append(f"{t(c, 'field')} {t(c, 'operator')} {val(c.find(NS + 'value'))}")
    return ' ; '.join(out)


def assigns(el, tag='inputAssignments'):
    return ', '.join(f"{t(a, 'field')}={val(a.find(NS + 'value'))}" for a in el.findall(NS + tag))


def conn(el):
    parts = []
    for tag in ('connector', 'defaultConnector', 'faultConnector', 'nextValueConnector', 'noMoreValuesConnector'):
        c = el.find(NS + tag)
        if c is not None:
            parts.append(f"{tag.replace('Connector', '') or 'next'}->{t(c, 'targetReference')}")
    return ' '.join(parts)


for f in sys.argv[1:]:
    r = ET.parse(f).getroot()
    print('=' * 100)
    print(f.split('/')[-1].split('\\')[-1], '|', t(r, 'label'), '|', t(r, 'processType'), '|', t(r, 'status'), '| runInMode:', t(r, 'runInMode'))
    desc = t(r, 'description')
    if desc:
        print('  desc:', desc[:600])
    s = r.find(NS + 'start')
    if s is not None:
        print(f"  START object={t(s, 'object')} trigger={t(s, 'recordTriggerType')} when={t(s, 'triggerType')} "
              f"entry={t(s, 'doesRequireRecordChangedToMeetCriteria')} filters: {conds(s) or filters(s)} {t(s, 'filterFormula') or ''} -> {conn(s)}")
        for sp in s.findall(NS + 'scheduledPaths'):
            print(f"    scheduled: {t(sp, 'name')} offset={t(sp, 'offsetNumber')} {t(sp, 'offsetUnit')} {t(sp, 'timeSource')} {t(sp, 'recordField')} -> {conn(sp)}")
    for v in r.findall(NS + 'variables'):
        print(f"  var {t(v, 'name')}: {t(v, 'dataType')} {t(v, 'objectType') or ''} in={t(v, 'isInput')} out={t(v, 'isOutput')}")
    for fm in r.findall(NS + 'formulas'):
        print(f"  formula {t(fm, 'name')}: {(t(fm, 'expression') or '')[:400]}")
    for tt in r.findall(NS + 'textTemplates'):
        print(f"  textTemplate {t(tt, 'name')}: {(t(tt, 'text') or '')[:500]}")
    for kind in ('decisions', 'screens', 'recordLookups', 'recordCreates', 'recordUpdates', 'recordDeletes',
                 'actionCalls', 'assignments', 'loops', 'subflows', 'customErrors'):
        for e in r.findall(NS + kind):
            name = t(e, 'name')
            line = f"  [{kind}] {name} ({t(e, 'label')})"
            if kind == 'decisions':
                print(line, '| default->', t(e, 'defaultConnector/targetReference'))
                for rule in e.findall(NS + 'rules'):
                    print(f"      rule {t(rule, 'name')} ({t(rule, 'label')}): {conds(rule)} -> {t(rule, 'connector/targetReference')}")
            elif kind == 'screens':
                print(line, conn(e), '| next:', t(e, 'nextOrFinishButtonLabel'), 'back:', t(e, 'allowBack'))
                for fld in e.iter(NS + 'fields'):
                    ft = (t(fld, 'fieldText') or '')[:300].replace('\n', ' ')
                    vis = fld.find(NS + 'visibilityRule')
                    print(f"      field {t(fld, 'name')} type={t(fld, 'fieldType')} dt={t(fld, 'dataType')} req={t(fld, 'isRequired')} "
                          f"src={t(fld, 'objectFieldReference')} {('text: ' + ft) if ft else ''} {('VIS ' + conds(vis)) if vis is not None else ''}")
                    vr = fld.find(NS + 'validationRule')
                    if vr is not None:
                        print(f"        validation: {t(vr, 'formulaExpression')} / {t(vr, 'errorMessage')}")
            elif kind in ('recordLookups',):
                print(line, f"obj={t(e, 'object')} filters: {filters(e)} first={t(e, 'getFirstRecordOnly')} store={t(e, 'outputReference')}", conn(e))
            elif kind in ('recordCreates', 'recordUpdates', 'recordDeletes'):
                print(line, f"obj={t(e, 'object')} ref={t(e, 'inputReference')} filters: {filters(e)} set: {assigns(e)}", conn(e))
            elif kind == 'actionCalls':
                print(line, f"action={t(e, 'actionName')} type={t(e, 'actionType')} params: {', '.join(f'{t(p, chr(110)+chr(97)+chr(109)+chr(101))}={val(p.find(NS + chr(118)+chr(97)+chr(108)+chr(117)+chr(101)))}' for p in e.findall(NS + 'inputParameters'))}", conn(e))
            elif kind == 'assignments':
                items = ', '.join(f"{t(a, 'assignToReference')} {t(a, 'operator')} {val(a.find(NS + 'value'))}" for a in e.findall(NS + 'assignmentItems'))
                print(line, items, conn(e))
            elif kind == 'customErrors':
                msgs = ' | '.join((t(m, 'errorMessage') or '') for m in e.findall(NS + 'customErrorMessages'))
                print(line, msgs, conn(e))
            else:
                print(line, conn(e))
