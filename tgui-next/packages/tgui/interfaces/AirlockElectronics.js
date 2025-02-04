import { Fragment } from 'inferno';
import { act } from '../byond';
import { Box, Button, LabeledList, Section, Tabs } from '../components';

export const AirlockElectronics = props => {
  const { state } = props;
  const { config, data } = state;
  const { ref } = config;

  const regions = data.regions || [];

  const diffMap = {
    0: {
      icon: 'times-circle',
    },
    1: {
      icon: 'stop-circle',
    },
    2: {
      icon: 'check-circle',
    },
  };

  const checkAccessIcon = accesses => {
    let oneAccess = false;
    let oneInaccess = false;

    accesses.forEach(element => {
      if (element.req) {
        oneAccess = true;
      }
      else {
        oneInaccess = true;
      }
    });

    if (!oneAccess && oneInaccess) {
      return 0;
    }
    else if (oneAccess && oneInaccess) {
      return 1;
    }
    else {
      return 2;
    }
  };

  return (
    <Fragment>
      <Section title="Main">
        <LabeledList>
          <LabeledList.Item
            label="Access Required">
            <Button
              icon={data.oneAccess ? 'unlock' : 'lock'}
              content={data.oneAccess ? 'One' : 'All'}
              onClick={() => act(ref, 'one_access')}
            />
          </LabeledList.Item>
        </LabeledList>
      </Section>
      <Section title="Access">
        <Box height="261px">
          <Tabs vertical>
            {regions.map(region => {
              const { name } = region;
              const accesses = region.accesses || [];
              const icon = diffMap[checkAccessIcon(accesses)].icon;
              return (
                <Tabs.Tab
                  icon={icon}
                  label={name}>
                  {() => (
                    accesses.map(access => (
                      <Box>
                        <Button
                          icon={access.req ? 'check-square-o' : 'square-o' }
                          content={access.name}
                          selected={access.req}
                          onClick={() => act(ref, 'set', {
                            access: access.id,
                          })} />
                      </Box>
                    ))
                  )}
                </Tabs.Tab>
              );
            })}
          </Tabs>
        </Box>
      </Section>
    </Fragment>
  );
};
