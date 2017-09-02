import os
import sys

try:
    from importlib.util import find_spec
except ImportError:
    from collections import namedtuple
    from imp import find_module

    ModuleSpec = namedtuple(
        'ModuleSpec', ['origin', 'has_location', 'submodule_search_locations'])

    def find_spec(name):
        """Minimal implementation as required by `find`."""
        try:
            f, path, _ = find_module(name)
        except ImportError:
            return None
        has_location = path is not None
        if f is None:
            return ModuleSpec(None, has_location, [path])
        f.close()
        return ModuleSpec(path, has_location, None)


class ArgcompleteMarkerNotFound(RuntimeError):
    pass


def find(name, return_package=False):
    names = name.split('.')
    spec = find_spec(names[0])
    if spec is None:
        raise ArgcompleteMarkerNotFound(
            'no module named "{}"'.format(names[0]))
    if not spec.has_location:
        raise ArgcompleteMarkerNotFound('cannot locate file')
    if spec.submodule_search_locations is None:
        if len(names) != 1:
            raise ArgcompleteMarkerNotFound(
                '{} is not a package'.format(names[0]))
        return spec.origin
    if len(spec.submodule_search_locations) != 1:
        raise ArgcompleteMarkerNotFound('expecting one search location')
    path = os.path.join(spec.submodule_search_locations[0], *names[1:])
    if os.path.isdir(path):
        filename = '__main__.py'
        if return_package:
            filename = '__init__.py'
        return os.path.join(path, filename)
    else:
        return path + '.py'


def main():
    with open(find(sys.argv[1])) as f:
        head = f.read(1024)
    if 'PYTHON_ARGCOMPLETE_OK' not in head:
        raise ArgcompleteMarkerNotFound('marker not found')


if __name__ == '__main__':
    try:
        main()
    except ArgcompleteMarkerNotFound as e:
        sys.exit(e)
