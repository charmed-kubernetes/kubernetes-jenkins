import pytest
import rewrite_asserts
from utils import temporary_model, wait_for_ready, conjureup
from validation import validate_all

test_cases = [
    # namespace    # bundle                # channel  # snap channel
    ('containers', 'kubernetes-core',      'edge',    '1.6/stable'),
    ('containers', 'canonical-kubernetes', 'edge',    '1.6/stable'),
]


@pytest.mark.asyncio
@pytest.mark.parametrize('namespace,bundle,channel,snap_channel', test_cases)
async def test_deploy(namespace, bundle, channel, snap_channel):
    async with temporary_model() as model:
        await conjureup(namespace, bundle, channel, snap_channel, model)
        await wait_for_ready(model)
        await validate_all(model)
